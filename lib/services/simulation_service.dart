import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/facility.dart';
import '../models/inventory_item.dart';
import '../models/daily_usage_log.dart';

class SimulationService {
  final FirebaseFirestore _firestore;
  final Random _random = Random();

  SimulationService(this._firestore);

  // --- LOCATION & PROFILE SIMULATION ---

  Map<String, dynamic> generateRealisticProfile({String? type}) {
    // Center point: Delhi NCR (28.6139, 77.2090)
    final double centerLat = 28.61;
    final double centerLng = 77.20;
    
    // Add small random offset to cluster them (within ~50km)
    final double latOffset = (_random.nextDouble() - 0.5) * 0.4;
    final double lngOffset = (_random.nextDouble() - 0.5) * 0.4;
    
    final String assignedType = type ?? (_random.nextBool() ? 'urban' : 'rural');
    
    final List<String> regions = ['North District', 'South District', 'East State', 'West Sector', 'Central Zone'];
    final String region = regions[_random.nextInt(regions.length)];

    return {
      'type': assignedType,
      'latitude': centerLat + latOffset,
      'longitude': centerLng + lngOffset,
      'region': region,
      'createdAt': Timestamp.now(),
    };
  }

  // --- DAILY USAGE SIMULATION ---

  Future<void> runFullSimulation(String facilityId, String facilityType) async {
    // 1. Initialize Inventory if not exists
    await _seedInventory(facilityId);

    // 2. Simulate last 120 days using a single WriteBatch
    final now = DateTime.now();
    var batch = _firestore.batch();
    int writeCount = 0;

    for (int i = 120; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      _addSimulateDayToBatch(batch, facilityId, facilityType, date);
      writeCount++;

      // Batch limit is 500
      if (writeCount >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        writeCount = 0;
      }
    }
    
    if (writeCount > 0) {
      await batch.commit();
    }

    // 3. Reset inventory to realistic remaining levels after simulation
    await _resetInventoryLevels(facilityId);
  }

  Future<void> _resetInventoryLevels(String facilityId) async {
    final medsSnapshot = await _firestore
        .collection('inventory')
        .doc(facilityId)
        .collection('medicines')
        .get();

    for (var doc in medsSnapshot.docs) {
      final data = doc.data();
      final int initial = data['initialQuantity'] ?? 2000;
      // Set remaining to 30-70% of initial for realistic dashboard view
      final double factor = 0.3 + (_random.nextDouble() * 0.4);
      final int remaining = (initial * factor).round();
      await doc.reference.update({
        'remainingQuantity': remaining,
        'lastUpdated': Timestamp.now(),
      });
    }
  }

  Future<void> _seedInventory(String facilityId) async {
    final List<String> medicines = [
      'Paracetamol', 
      'Cough Syrup', 
      'ORS', 
      'Antibiotic', 
      'Vitamin Tablets'
    ];

    for (var med in medicines) {
      final medicineId = med.toLowerCase().replaceAll(' ', '_');
      final invRef = _firestore
          .collection('inventory')
          .doc(facilityId)
          .collection('medicines')
          .doc(medicineId);

      final snapshot = await invRef.get();
      if (!snapshot.exists) {
        final int initialQty = 2000 + _random.nextInt(3000);
        await invRef.set({
          'medicineName': med,
          'batchId': 'B-${1000 + _random.nextInt(9000)}',
          'initialQuantity': initialQty,
          'remainingQuantity': initialQty,
          'arrivalDate': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 130))),
          'expiryDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 365))),
          'lastUpdated': Timestamp.now(),
        });
      }
    }
  }

  void _addSimulateDayToBatch(WriteBatch batch, String facilityId, String facilityType, DateTime date) {
    // 1. Determine patient count
    int basePatients = facilityType == 'urban' ? 150 : 35;
    double variation = 0.8 + (_random.nextDouble() * 0.4); // 80% to 120%
    int totalPatients = (basePatients * variation).round();

    // 2. Generate medicine usage
    final List<String> medicines = ['Paracetamol', 'Cough Syrup', 'ORS', 'Antibiotic', 'Vitamin Tablets'];
    List<MedicineUsage> usages = [];
    final month = date.month;

    for (var med in medicines) {
      double usagePerPatient = 0.5; // base usage factor

      // Seasonal Influences
      if ((month >= 11 || month <= 2) && (med == 'Cough Syrup' || med == 'Paracetamol')) {
        usagePerPatient *= 2.5; // Winter spike
      } else if ((month >= 5 && month <= 8) && med == 'ORS') {
        usagePerPatient *= 3.0; // Summer spike
      }

      int unitsUsed = (totalPatients * usagePerPatient * (0.9 + _random.nextDouble() * 0.2)).round();
      usages.add(MedicineUsage(medicineName: med, unitsDistributed: unitsUsed));
    }

    // 3. Write Daily Log to Batch
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final logRef = _firestore
        .collection('daily_usage_logs')
        .doc(facilityId)
        .collection('logs')
        .doc(dateStr);

    batch.set(logRef, {
      'date': Timestamp.fromDate(date),
      'medicines': usages.map((u) => u.toMap()).toList(),
      'totalPatients': totalPatients,
    });
  }
}
