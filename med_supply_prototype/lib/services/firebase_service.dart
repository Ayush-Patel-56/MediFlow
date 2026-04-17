import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/facility.dart';
import '../models/inventory_item.dart';
import '../models/usage_log.dart';
import '../models/request.dart';

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService(FirebaseFirestore.instance);
});

class FirebaseService {
  final FirebaseFirestore _firestore;

  FirebaseService(this._firestore);

  // Auth/Role
  Future<List<Facility>> getFacilities() async {
    final snapshot = await _firestore.collection('facilities').get();
    return snapshot.docs.map((doc) => Facility.fromMap(doc.data(), doc.id)).toList();
  }

  // Inventory
  Stream<List<InventoryItem>> streamInventory(String facilityId) {
    return _firestore
        .collection('inventory')
        .where('facilityId', isEqualTo: facilityId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => InventoryItem.fromMap(doc.data(), doc.id)).toList());
  }

  Stream<List<InventoryItem>> streamAllInventory() {
    return _firestore
        .collection('inventory')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => InventoryItem.fromMap(doc.data(), doc.id)).toList());
  }

  // Requests
  Stream<List<MedRequest>> streamRequests(String? facilityId) {
    var query = _firestore.collection('requests');
    if (facilityId != null) {
      query = query.where('facilityId', isEqualTo: facilityId) as CollectionReference<Map<String, dynamic>>;
    }
    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) => MedRequest.fromMap(doc.data(), doc.id)).toList());
  }
  
  Future<void> addRequest(MedRequest request) async {
    await _firestore.collection('requests').add(request.toMap());
  }

  // Usage Logs
  Future<List<UsageLog>> getUsageLogs(String facilityId, String medicineName, {int days = 120}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final snapshot = await _firestore
        .collection('usage_logs')
        .where('facilityId', isEqualTo: facilityId)
        .where('medicineName', isEqualTo: medicineName)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs.map((doc) => UsageLog.fromMap(doc.data(), doc.id)).toList();
  }

  Future<void> addUsageLog(UsageLog log) async {
    await _firestore.collection('usage_logs').add(log.toMap());
    
    // Also deduct from inventory
    final invSnapshot = await _firestore
        .collection('inventory')
        .where('facilityId', isEqualTo: log.facilityId)
        .where('medicineName', isEqualTo: log.medicineName)
        .get();
        
    for (var doc in invSnapshot.docs) {
      final current = doc.data()['currentQuantity'] as int;
      if (current > 0) {
        final deduct = min(current, log.quantityUsed);
        await doc.reference.update({'currentQuantity': current - deduct});
        break; // Simplified: deducts from first batch found
      }
    }
  }

  // LOG USAGE (For Daily Logging Page)
  Future<void> logUsage({
    required String facilityId,
    required String medicineName,
    required int quantity,
    required int patients,
  }) async {
    final logRef = _firestore.collection('usage_logs').doc();
    await logRef.set({
      'facilityId': facilityId,
      'medicineName': medicineName,
      'date': Timestamp.now(),
      'quantityUsed': quantity,
      'patientsTreated': patients,
    });
  }

  // SEED DATABASE FOR PROTOTYPE
  Future<void> seedDatabase() async {
    final random = Random();
    final List<Map<String, dynamic>> initialFacilities = [
      {'name': 'Delhi City Hospital', 'type': 'Hospital', 'lat': 28.6139, 'lng': 77.2090},
      {'name': 'Gurugram Rural Clinic', 'type': 'Primary Health Center', 'lat': 28.4595, 'lng': 77.0266},
      {'name': 'Noida Community Center', 'type': 'Community Health Center', 'lat': 28.5355, 'lng': 77.3910},
    ];

    final List<String> medicines = ['Paracetamol', 'Amoxicillin', 'Ibuprofen', 'Cetirizine', 'Azithromycin'];

    var batch = _firestore.batch();
    int commitCount = 0;

    for (var f in initialFacilities) {
      final facRef = _firestore.collection('facilities').doc();
      batch.set(facRef, {
        'name': f['name'],
        'email': '${f['name'].toString().split(' ').first.toLowerCase()}@mediflow.com',
        'type': f['type'],
        'latitude': f['lat'],
        'longitude': f['lng'],
      });
      commitCount++;

      for (var med in medicines) {
        // Create Inventory
        final invRef = _firestore.collection('inventory').doc();
        batch.set(invRef, {
          'facilityId': facRef.id,
          'medicineName': med,
          'batchId': 'B-${random.nextInt(10000)}',
          'arrivalDate': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 120))),
          'batchDurationDays': 365,
          'expiryDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 245))),
          'initialQuantity': 5000 + random.nextInt(5000),
          'currentQuantity': 1000 + random.nextInt(3000),
          'unit': 'strips',
        });
        commitCount++;

        // Write usage logs
        for (int i = 0; i < 120; i++) {
          final logRef = _firestore.collection('usage_logs').doc();
          final date = DateTime.now().subtract(Duration(days: i));
          int baseUsage = 10 + random.nextInt(20);
          if (med == 'Cetirizine' && (date.month == 11 || date.month == 12 || date.month == 1 || date.month == 2)) {
             baseUsage += 15;
          }

          batch.set(logRef, {
            'facilityId': facRef.id,
            'medicineName': med,
            'date': Timestamp.fromDate(date),
            'quantityUsed': baseUsage,
            'patientsTreated': (baseUsage * 0.8).round(),
          });
          commitCount++;

          if (commitCount > 400) {
            await batch.commit();
            batch = _firestore.batch();
            commitCount = 0;
          }
        }
      }
    }
    
    if (commitCount > 0) {
      await batch.commit();
    }
  }
}
