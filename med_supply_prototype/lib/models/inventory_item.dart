import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryItem {
  final String id;
  final String facilityId;
  final String medicineName;
  final String batchId;
  final DateTime arrivalDate;
  final int batchDurationDays; // e.g., 365 for 1 yr
  final DateTime expiryDate;
  final int initialQuantity;
  final int currentQuantity;
  final String unit; // e.g., 'tablets', 'bottles'

  InventoryItem({
    required this.id,
    required this.facilityId,
    required this.medicineName,
    required this.batchId,
    required this.arrivalDate,
    required this.batchDurationDays,
    required this.expiryDate,
    required this.initialQuantity,
    required this.currentQuantity,
    required this.unit,
  });

  factory InventoryItem.fromMap(Map<String, dynamic> map, String id) {
    return InventoryItem(
      id: id,
      facilityId: map['facilityId'] ?? '',
      medicineName: map['medicineName'] ?? '',
      batchId: map['batchId'] ?? '',
      arrivalDate: (map['arrivalDate'] as Timestamp).toDate(),
      batchDurationDays: map['batchDurationDays']?.toInt() ?? 0,
      expiryDate: (map['expiryDate'] as Timestamp).toDate(),
      initialQuantity: map['initialQuantity']?.toInt() ?? 0,
      currentQuantity: map['currentQuantity']?.toInt() ?? 0,
      unit: map['unit'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'facilityId': facilityId,
      'medicineName': medicineName,
      'batchId': batchId,
      'arrivalDate': Timestamp.fromDate(arrivalDate),
      'batchDurationDays': batchDurationDays,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'initialQuantity': initialQuantity,
      'currentQuantity': currentQuantity,
      'unit': unit,
    };
  }
}
