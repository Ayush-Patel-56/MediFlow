import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/request.dart';
import 'firebase_service.dart';

final toolDispatcherProvider = Provider<ToolDispatcher>((ref) {
  return ToolDispatcher(ref.read(firebaseServiceProvider));
});

class ToolDispatcher {
  final FirebaseService _firebaseService;

  ToolDispatcher(this._firebaseService);

  Future<Map<String, Object?>> dispatch(FunctionCall call) async {
    try {
      switch (call.name) {
        case 'report_shortage':
          final facilityId = call.args['facilityId'] as String;
          final medicineName = call.args['medicineName'] as String;
          final quantity = (call.args['quantity'] as num).toInt();
          
          await _firebaseService.addRequest(MedRequest(
            id: '', // Firestore auto-generates
            facilityId: facilityId,
            medicineName: medicineName,
            type: RequestType.shortage,
            quantity: quantity,
            requestDate: DateTime.now(),
            status: RequestStatus.pending,
            notes: 'AI generated shortage report',
          ));
          return {'status': 'success', 'details': 'Shortage reported for $quantity of $medicineName'};

        case 'report_surplus':
          final facilityId = call.args['facilityId'] as String;
          final medicineName = call.args['medicineName'] as String;
          final quantity = (call.args['quantity'] as num).toInt();
          
          await _firebaseService.addRequest(MedRequest(
            id: '',
            facilityId: facilityId,
            medicineName: medicineName,
            type: RequestType.surplus,
            quantity: quantity,
            requestDate: DateTime.now(),
            status: RequestStatus.pending,
            notes: 'AI generated surplus report',
          ));
          return {'status': 'success', 'details': 'Surplus reported for $quantity of $medicineName'};
          
        case 'check_system_inventory':
          // Fetch across facilities
          final facilities = await _firebaseService.getFacilities();
          Map<String, dynamic> systemStock = {};
          
          for (var fac in facilities) {
             final inv = await _firebaseService.getInventoryOnce(fac.id);
             systemStock[fac.name] = inv.map((i) => {
               'name': i.medicineName,
               'remaining': i.remainingQuantity,
               'initial': i.initialQuantity,
             }).toList();
          }
          return {'status': 'success', 'system_inventory': systemStock};

        default:
          return {'status': 'error', 'details': 'Unknown function call: ${call.name}'};
      }
    } catch (e) {
      return {'status': 'error', 'details': 'Failed to execute ${call.name}: $e'};
    }
  }
}
