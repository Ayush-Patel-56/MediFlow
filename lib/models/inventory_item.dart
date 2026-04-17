import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryItem {
  final String id;
  final String medicineName;
  final String batchId;
  final DateTime arrivalDate;
  final DateTime expiryDate;
  final int initialQuantity;
  final int remainingQuantity;
  final DateTime lastUpdated;

  InventoryItem({
    required this.id,
    required this.medicineName,
    required this.batchId,
    required this.arrivalDate,
    required this.expiryDate,
    required this.initialQuantity,
    required this.remainingQuantity,
    required this.lastUpdated,
  });

  factory InventoryItem.fromMap(Map<String, dynamic> map, String id) {
    return InventoryItem(
      id: id,
      medicineName: map['medicineName'] ?? '',
      batchId: map['batchId'] ?? '',
      arrivalDate: (map['arrivalDate'] as Timestamp).toDate(),
      expiryDate: (map['expiryDate'] as Timestamp).toDate(),
      initialQuantity: map['initialQuantity']?.toInt() ?? 0,
      remainingQuantity: map['remainingQuantity']?.toInt() ?? 0,
      lastUpdated: map['lastUpdated'] != null 
          ? (map['lastUpdated'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'medicineName': medicineName,
      'batchId': batchId,
      'arrivalDate': Timestamp.fromDate(arrivalDate),
      'expiryDate': Timestamp.fromDate(expiryDate),
      'initialQuantity': initialQuantity,
      'remainingQuantity': remainingQuantity,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}
