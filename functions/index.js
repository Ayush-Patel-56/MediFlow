const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");

admin.initializeApp();

// Initialize Gemini 1.5 Pro
// NOTE: GEMINI_API_KEY must be set in Firebase Secrets
// Use: firebase functions:secrets:set GEMINI_API_KEY
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "AIza_FAKE_KEY");

/**
 * 1. forecastDemand(facilityId, medicineNames[])
 * Calls Gemini to predict demand based on 90-day history.
 */
exports.forecastDemand = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User must log in');

  const { facilityId, medicineNames } = data;
  const db = admin.firestore();

  // 1. Fetch facility details
  const facilityDoc = await db.collection("facilities").doc(facilityId).get();
  const facility = facilityDoc.data();

  // 2. Fetch last 90 days of usage_logs
  const ninetyDaysAgo = new Date();
  ninetyDaysAgo.setDate(ninetyDaysAgo.getDate() - 90);
  
  const usageQuery = await db.collection("facilities")
    .doc(facilityId)
    .collection("usage_logs")
    .where("loggedAt", ">=", admin.firestore.Timestamp.fromDate(ninetyDaysAgo))
    .get();

  const usageHistory = usageQuery.docs.map(doc => doc.data());

  // 3. Fetch current stock levels
  const stocksQuery = await db.collection("facilities")
    .doc(facilityId)
    .collection("stocks")
    .get();
  
  const currentStocks = stocksQuery.docs.map(doc => ({
    medicineName: doc.data().medicineName,
    qtyRemaining: doc.data().qtyRemaining
  }));

  // 4. Construct Gemini Prompt
  const model = genAI.getGenerativeModel({ model: "gemini-1.5-pro" });
  const prompt = `
    SYSTEM: You are a medical supply chain forecasting AI. Analyze the provided 90-day usage history for a healthcare facility and predict demand for the next 30 days per medicine. Be conservative. Account for seasonal spikes. Return ONLY valid JSON matching the schema.

    USER: 
    Facility: ${facility.name}. District: ${facility.district}.
    Historical Usage Data (last 90 days): ${JSON.stringify(usageHistory)}
    Current Stock Levels: ${JSON.stringify(currentStocks)}
    Target Medicines: ${medicineNames.join(", ")}

    JSON Schema response (enforce strictly):
    {
      "forecasts": [
        {
          "medicineName": "string",
          "predictedQty30Days": "integer",
          "reorderRecommended": "boolean",
          "confidence": "low|medium|high",
          "rationale": "string (max 30 words)"
        }
      ],
      "overallRiskLevel": "low|medium|critical",
      "summary": "string (max 50 words)"
    }
  `;

  try {
    const result = await model.generateContent(prompt);
    const responseText = result.response.text();
    // Use regex to extract JSON if Gemini wraps it in markdown blocks
    const jsonMatch = responseText.match(/\{[\s\S]*\}/);
    return JSON.parse(jsonMatch ? jsonMatch[0] : responseText);
  } catch (error) {
    console.error("Gemini Error:", error);
    throw new functions.https.HttpsError('internal', 'AI forecasting failed');
  }
});

/**
 * 2. checkLowStock() - Scheduled daily CRON
 * Scans all facilities and creates alerts.
 */
exports.checkLowStock = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
  const db = admin.firestore();
  const facilities = await db.collection("facilities").get();

  for (const facilityDoc of facilities.docs) {
    const stocks = await db.collection("facilities")
      .doc(facilityDoc.id)
      .collection("stocks")
      .where("qtyRemaining", "<=", "reorderLevel") // Note: Firestore doesn't support field-to-field comparison natively, so we fetch and filter
      .get();

    for (const stockDoc of stocks.docs) {
      const stock = stockDoc.data();
      if (stock.qtyRemaining <= stock.reorderLevel) {
        // Create an alert document
        await db.collection("alerts").add({
          facilityId: facilityDoc.id,
          facilityName: facilityDoc.data().name,
          stockId: stockDoc.id,
          medicineName: stock.medicineName,
          qtyRemaining: stock.qtyRemaining,
          reorderLevel: stock.reorderLevel,
          type: "low_stock",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false
        });

        // Trigger FCM Notification (Assuming FCM token is stored in the facility's user doc)
        const userQuery = await db.collection("users")
          .where("facilityId", "==", facilityDoc.id)
          .where("role", "==", "facility_head")
          .limit(1)
          .get();

        if (!userQuery.empty) {
          const user = userQuery.docs[0].data();
          if (user.fcmToken) {
            await admin.messaging().send({
              token: user.fcmToken,
              notification: {
                title: "Low Stock Alert",
                body: `${stock.medicineName} is below reorder level (${stock.qtyRemaining} left).`
              }
            });
          }
        }
      }
    }
  }
  return null;
});

/**
 * 3. autoRedistribute(requestId)
 * Atomic stock transfer when a request is approved.
 */
exports.onIndentApproved = functions.firestore
  .document('requests/{requestId}')
  .onUpdate(async (change, context) => {
    const beforeStatus = change.before.data().status;
    const after = change.after.data();
    
    // Only fire if status changed to 'approved'
    if (beforeStatus === 'pending' && after.status === 'approved') {
      const db = admin.firestore();
      
      const { fromFacilityId, toFacilityId, medicineName, qtyRequested } = after;

      // 1. Find source stock (toFacilityId - the surplus provider)
      const sourceStockQuery = await db.collection("facilities")
        .doc(toFacilityId)
        .collection("stocks")
        .where("medicineName", "==", medicineName)
        .limit(1)
        .get();

      // 2. Find destination stock (fromFacilityId - the requester)
      const destStockQuery = await db.collection("facilities")
        .doc(fromFacilityId)
        .collection("stocks")
        .where("medicineName", "==", medicineName)
        .limit(1)
        .get();

      if (sourceStockQuery.empty || destStockQuery.empty) {
        console.error("Stock documents not found for redistribution");
        return;
      }

      const sourceDoc = sourceStockQuery.docs[0];
      const destDoc = destStockQuery.docs[0];

      // 3. Execute atomic batch write
      const batch = db.batch();
      
      // Decrement source
      batch.update(sourceDoc.ref, {
        qtyRemaining: admin.firestore.FieldValue.increment(-qtyRequested),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Increment destination
      batch.update(destDoc.ref, {
        qtyRemaining: admin.firestore.FieldValue.increment(qtyRequested),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Update request resolution
      batch.update(change.after.ref, {
        resolvedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      await batch.commit();
      console.log(`Redistribution successful: ${qtyRequested} units of ${medicineName} from ${toFacilityId} to ${fromFacilityId}`);
    }
  });
