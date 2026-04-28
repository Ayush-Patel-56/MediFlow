const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const { BigQuery } = require("@google-cloud/bigquery");

admin.initializeApp();

const bigquery = new BigQuery();
const BQ_DATASET = process.env.BQ_DATASET || "mediflow_analytics";
const BQ_LOCATION = process.env.BQ_LOCATION || "US";
const tableReady = new Map();

// Initialize Gemini 1.5 Pro
// NOTE: GEMINI_API_KEY must be set in Firebase Secrets
// Use: firebase functions:secrets:set GEMINI_API_KEY
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "AIza_FAKE_KEY");

const BIGQUERY_TABLES = {
  ai_decisions: {
    schema: [
      { name: "decision_id", type: "STRING", mode: "REQUIRED" },
      { name: "occurred_at", type: "TIMESTAMP" },
      { name: "facility_id", type: "STRING" },
      { name: "medicine_name", type: "STRING" },
      { name: "decision_type", type: "STRING" },
      { name: "model", type: "STRING" },
      { name: "prediction", type: "INTEGER" },
      { name: "confidence", type: "STRING" },
      { name: "recommendation", type: "STRING" },
      { name: "reasoning", type: "STRING" },
      { name: "period_days", type: "INTEGER" },
      { name: "input_json", type: "STRING" },
      { name: "output_json", type: "STRING" },
    ],
  },
  transfer_requests: {
    schema: [
      { name: "request_id", type: "STRING", mode: "REQUIRED" },
      { name: "facility_id", type: "STRING" },
      { name: "medicine_name", type: "STRING" },
      { name: "request_type", type: "STRING" },
      { name: "quantity", type: "INTEGER" },
      { name: "status", type: "STRING" },
      { name: "request_date", type: "TIMESTAMP" },
      { name: "notes", type: "STRING" },
      { name: "captured_at", type: "TIMESTAMP" },
      { name: "payload_json", type: "STRING" },
    ],
  },
  inventory_snapshots: {
    schema: [
      { name: "snapshot_id", type: "STRING", mode: "REQUIRED" },
      { name: "facility_id", type: "STRING" },
      { name: "medicine_id", type: "STRING" },
      { name: "medicine_name", type: "STRING" },
      { name: "batch_id", type: "STRING" },
      { name: "initial_quantity", type: "INTEGER" },
      { name: "remaining_quantity", type: "INTEGER" },
      { name: "unit", type: "STRING" },
      { name: "expiry_date", type: "DATE" },
      { name: "arrival_date", type: "DATE" },
      { name: "stock_pct", type: "FLOAT" },
      { name: "status", type: "STRING" },
      { name: "captured_at", type: "TIMESTAMP" },
      { name: "payload_json", type: "STRING" },
    ],
  },
  usage_analytics: {
    schema: [
      { name: "usage_id", type: "STRING", mode: "REQUIRED" },
      { name: "facility_id", type: "STRING" },
      { name: "log_id", type: "STRING" },
      { name: "usage_date", type: "DATE" },
      { name: "medicine_name", type: "STRING" },
      { name: "units_distributed", type: "INTEGER" },
      { name: "total_patients", type: "INTEGER" },
      { name: "captured_at", type: "TIMESTAMP" },
      { name: "payload_json", type: "STRING" },
    ],
  },
  audit_events: {
    schema: [
      { name: "event_id", type: "STRING", mode: "REQUIRED" },
      { name: "occurred_at", type: "TIMESTAMP" },
      { name: "actor_id", type: "STRING" },
      { name: "source", type: "STRING" },
      { name: "entity_type", type: "STRING" },
      { name: "entity_id", type: "STRING" },
      { name: "action", type: "STRING" },
      { name: "facility_id", type: "STRING" },
      { name: "medicine_name", type: "STRING" },
      { name: "before_json", type: "STRING" },
      { name: "after_json", type: "STRING" },
      { name: "metadata_json", type: "STRING" },
    ],
  },
};

function safeJson(value) {
  return JSON.stringify(value ?? null, (_, v) => {
    if (v && typeof v.toDate === "function") return v.toDate().toISOString();
    return v;
  });
}

function toIsoTimestamp(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  return value;
}

function toBigQueryDate(value) {
  const iso = toIsoTimestamp(value);
  return iso ? iso.substring(0, 10) : null;
}

function stockStatus(data) {
  const initial = Number(data.initialQuantity || 0);
  const remaining = Number(data.remainingQuantity || 0);
  const pct = initial > 0 ? remaining / initial : 0;
  const expiry = toIsoTimestamp(data.expiryDate);
  const daysLeft = expiry ? Math.ceil((new Date(expiry).getTime() - Date.now()) / 86400000) : null;

  if (daysLeft !== null && daysLeft < 0) return "expired";
  if (pct >= 0.7 && daysLeft !== null && daysLeft <= 30) return "wastage_risk";
  if (pct <= 0.2 || remaining <= 500) return "low_stock";
  if (daysLeft !== null && daysLeft <= 30) return "expiring_soon";
  return "healthy";
}

async function ensureBigQueryTable(tableName) {
  if (tableReady.has(tableName)) return tableReady.get(tableName);

  const promise = (async () => {
    const dataset = bigquery.dataset(BQ_DATASET);
    const [datasetExists] = await dataset.exists();
    if (!datasetExists) {
      await bigquery.createDataset(BQ_DATASET, { location: BQ_LOCATION });
    }

    const table = dataset.table(tableName);
    const [tableExists] = await table.exists();
    if (!tableExists) {
      await dataset.createTable(tableName, {
        schema: { fields: BIGQUERY_TABLES[tableName].schema },
        timePartitioning: { type: "DAY" },
      });
    }
    return table;
  })();

  tableReady.set(tableName, promise);
  return promise;
}

async function insertBigQuery(tableName, rows) {
  const rowList = Array.isArray(rows) ? rows : [rows];
  if (rowList.length === 0) return;

  try {
    const table = await ensureBigQueryTable(tableName);
    await table.insert(rowList, {
      ignoreUnknownValues: true,
      skipInvalidRows: true,
    });
  } catch (error) {
    console.error(`BigQuery insert failed for ${tableName}`, error);
  }
}

async function auditEvent({ eventId, action, entityType, entityId, before, after, facilityId, medicineName, metadata, actorId = null }) {
  await insertBigQuery("audit_events", {
    event_id: eventId,
    occurred_at: new Date().toISOString(),
    actor_id: actorId,
    source: "firestore",
    entity_type: entityType,
    entity_id: entityId,
    action,
    facility_id: facilityId || after?.facilityId || before?.facilityId || null,
    medicine_name: medicineName || after?.medicineName || before?.medicineName || null,
    before_json: safeJson(before),
    after_json: safeJson(after),
    metadata_json: safeJson(metadata),
  });
}

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
 * 1b. logAIDecision()
 * Explicit audit hook for client-side AI forecasts and stock-analysis decisions.
 */
exports.logAIDecision = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "User must log in");

  const decisionId = data.decisionId || `${Date.now()}_${Math.random().toString(36).slice(2)}`;
  await insertBigQuery("ai_decisions", {
    decision_id: decisionId,
    occurred_at: new Date().toISOString(),
    facility_id: data.facilityId || null,
    medicine_name: data.medicineName || null,
    decision_type: data.decisionType || "stock_analysis",
    model: data.model || "client_ai",
    prediction: Number.isFinite(Number(data.prediction)) ? Number(data.prediction) : null,
    confidence: data.confidence || null,
    recommendation: data.recommendation || null,
    reasoning: data.reasoning || null,
    period_days: Number.isFinite(Number(data.periodDays)) ? Number(data.periodDays) : null,
    input_json: safeJson(data.input),
    output_json: safeJson(data.output),
  });

  await auditEvent({
    eventId: `ai_${decisionId}`,
    action: "ai_decision_logged",
    entityType: "ai_decision",
    entityId: decisionId,
    facilityId: data.facilityId,
    medicineName: data.medicineName,
    after: data,
    actorId: context.auth.uid,
  });

  return { ok: true, decisionId };
});

/**
 * 1c. Firestore -> BigQuery mirrors for analytics, transfer decisions, and audit.
 */
exports.mirrorRequestToBigQuery = functions.firestore
  .document("requests/{requestId}")
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    const requestId = context.params.requestId;
    const rowData = after || before || {};
    const action = !before && after ? "created" : before && after ? "updated" : "deleted";

    await insertBigQuery("transfer_requests", {
      request_id: requestId,
      facility_id: rowData.facilityId || null,
      medicine_name: rowData.medicineName || null,
      request_type: rowData.type || null,
      quantity: Number(rowData.quantity || 0),
      status: after ? rowData.status || null : "deleted",
      request_date: toIsoTimestamp(rowData.requestDate),
      notes: rowData.notes || null,
      captured_at: new Date().toISOString(),
      payload_json: safeJson(rowData),
    });

    await auditEvent({
      eventId: `request_${requestId}_${Date.now()}`,
      action: `request_${action}`,
      entityType: "request",
      entityId: requestId,
      before,
      after,
      facilityId: rowData.facilityId,
      medicineName: rowData.medicineName,
    });

    if (after?.notes && String(after.notes).toLowerCase().includes("ai predicted")) {
      await insertBigQuery("ai_decisions", {
        decision_id: `request_${requestId}_${Date.now()}`,
        occurred_at: new Date().toISOString(),
        facility_id: after.facilityId || null,
        medicine_name: after.medicineName || null,
        decision_type: after.type === "surplus" ? "redistribution_recommendation" : "restock_recommendation",
        model: "mediflow_stock_analysis",
        prediction: null,
        confidence: null,
        recommendation: after.type || null,
        reasoning: after.notes || null,
        period_days: null,
        input_json: null,
        output_json: safeJson(after),
      });
    }
  });

exports.mirrorInventoryToBigQuery = functions.firestore
  .document("inventory/{facilityId}/medicines/{medicineId}")
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    const data = after || before || {};
    const facilityId = context.params.facilityId;
    const medicineId = context.params.medicineId;
    const initial = Number(data.initialQuantity || 0);
    const remaining = Number(data.remainingQuantity || 0);
    const action = !before && after ? "created" : before && after ? "updated" : "deleted";

    await insertBigQuery("inventory_snapshots", {
      snapshot_id: `${facilityId}_${medicineId}_${Date.now()}`,
      facility_id: facilityId,
      medicine_id: medicineId,
      medicine_name: data.medicineName || null,
      batch_id: data.batchId || null,
      initial_quantity: initial,
      remaining_quantity: remaining,
      unit: data.unit || null,
      expiry_date: toBigQueryDate(data.expiryDate),
      arrival_date: toBigQueryDate(data.arrivalDate),
      stock_pct: initial > 0 ? remaining / initial : null,
      status: after ? stockStatus(data) : "deleted",
      captured_at: new Date().toISOString(),
      payload_json: safeJson(data),
    });

    await auditEvent({
      eventId: `inventory_${facilityId}_${medicineId}_${Date.now()}`,
      action: `inventory_${action}`,
      entityType: "inventory",
      entityId: medicineId,
      before,
      after,
      facilityId,
      medicineName: data.medicineName,
    });
  });

exports.mirrorUsageLogToBigQuery = functions.firestore
  .document("daily_usage_logs/{facilityId}/logs/{logId}")
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    const data = after || before || {};
    const facilityId = context.params.facilityId;
    const logId = context.params.logId;
    const medicines = Array.isArray(data.medicines) ? data.medicines : [];
    const action = !before && after ? "created" : before && after ? "updated" : "deleted";

    await insertBigQuery("usage_analytics", medicines.map((medicine, index) => ({
      usage_id: `${facilityId}_${logId}_${index}_${Date.now()}`,
      facility_id: facilityId,
      log_id: logId,
      usage_date: toBigQueryDate(data.date),
      medicine_name: medicine.medicineName || null,
      units_distributed: Number(medicine.unitsDistributed || 0),
      total_patients: Number(data.totalPatients || 0),
      captured_at: new Date().toISOString(),
      payload_json: safeJson(data),
    })));

    await auditEvent({
      eventId: `usage_${facilityId}_${logId}_${Date.now()}`,
      action: `usage_log_${action}`,
      entityType: "daily_usage_log",
      entityId: logId,
      before,
      after,
      facilityId,
    });
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
