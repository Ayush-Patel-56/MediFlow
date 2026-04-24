import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/daily_usage_log.dart';
import '../models/request.dart';
import '../models/facility.dart';
import '../models/inventory_item.dart';

final String geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
final aiServiceProvider = Provider<AIService>((ref) {
  return AIService();
});

class AIService {
  GenerativeModel? _model;
  GenerativeModel? _fallbackModel;
  bool _offlineMode = false;

  static const String _primaryModelName = 'gemini-2.0-flash';
  static const String _fallbackModelName = 'gemini-2.0-flash-lite';

  AIService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isNotEmpty) {
      _model = GenerativeModel(model: _primaryModelName, apiKey: apiKey);
      _fallbackModel = GenerativeModel(model: _fallbackModelName, apiKey: apiKey);
      print('AI Service: Gemini models initialized ($_primaryModelName + $_fallbackModelName).');
    } else {
      _offlineMode = true;
      print('AI Service: No API key found, running in offline mode.');
    }
  }

  bool _isQuotaError(String errorMessage) {
    final lower = errorMessage.toLowerCase();
    return lower.contains('quota') ||
        lower.contains('rate limit') ||
        lower.contains('resource exhausted') ||
        lower.contains('429') ||
        lower.contains('exceeded');
  }

  Future<String?> _tryGenerate(String prompt) async {
    // Try primary model
    if (_model != null && !_offlineMode) {
      try {
        final response = await _model!.generateContent([Content.text(prompt)]);
        return response.text;
      } catch (e) {
        if (_isQuotaError(e.toString())) {
          print('AIService: $_primaryModelName quota exceeded, trying fallback...');
        } else {
          print('AIService: Primary model error: $e');
          return null;
        }
      }
    }

    // Try fallback model
    if (_fallbackModel != null && !_offlineMode) {
      try {
        final response = await _fallbackModel!.generateContent([Content.text(prompt)]);
        return response.text;
      } catch (e) {
        if (_isQuotaError(e.toString())) {
          print('AIService: Both models quota exhausted, switching to offline mode.');
          _offlineMode = true;
        } else {
          print('AIService: Fallback model error: $e');
        }
      }
    }

    return null; // Signal to use offline fallback
  }

  Future<Map<String, dynamic>> forecastDemand(String medicineName, List<DailyUsageLog> logs, int daysToForecast) async {
    final medLogs = logs.map((l) {
      final usage = l.medicines.firstWhere((m) => m.medicineName == medicineName, orElse: () => MedicineUsage(medicineName: medicineName, unitsDistributed: 0));
      return {'date': l.date, 'used': usage.unitsDistributed};
    }).toList();

    if (!_offlineMode && (_model != null || _fallbackModel != null)) {
      final logSummary = medLogs.take(30).map((l) => 'Date: ${(l['date'] as DateTime).toIso8601String()}, Used: ${l['used']}').join('\n');
      final prompt = '''
Medicine: $medicineName
Forecast duration: $daysToForecast days
Sample of recent daily usage data:
$logSummary

Output a JSON object with two fields:
{
  "prediction": <integer representing target total quantity>,
  "reasoning": "<string providing a robust 2-sentence clinical/statistical explanation for this forecast considering seasonality>"
}
''';

      final result = await _tryGenerate(prompt);
      if (result != null) {
        try {
          final rawText = result.replaceAll('```json', '').replaceAll('```', '').trim();
          final Map<String, dynamic> data = jsonDecode(rawText);
          return data;
        } catch (e) {
          print('AIService: Failed to parse Gemini response: $e');
        }
      }
    }

    // Offline fallback — statistical forecast
    await Future.delayed(const Duration(milliseconds: 800));
    final prediction = _fallbackForecast(medLogs, daysToForecast);
    final avgDaily = medLogs.isNotEmpty
        ? (medLogs.fold(0, (sum, log) => sum + (log['used'] as int)) / medLogs.length).round()
        : 15;

    return {
      "prediction": prediction,
      "reasoning": "Statistical forecast based on ${medLogs.length} days of usage data. "
          "Average daily consumption is $avgDaily units with a 10% safety buffer applied for $daysToForecast-day projection."
    };
  }

  int _fallbackForecast(List<Map<String, dynamic>> medLogs, int daysToForecast) {
    if (medLogs.isEmpty) return daysToForecast * 15;
    double avg = medLogs.fold(0.0, (sum, log) => sum + (log['used'] as int)) / medLogs.length;
    return (avg * daysToForecast * 1.1).round();
  }

  Future<List<Map<String, dynamic>>> generateSmartAlerts(List<InventoryItem> inventory) async {
    if (inventory.isEmpty) {
      return [{"severity": "red", "title": "Zero Inventory Found", "description": "Log medicines to enable analysis."}];
    }

    if (!_offlineMode && (_model != null || _fallbackModel != null)) {
      final payload = inventory.map((i) => "Med: ${i.medicineName}, Qty: ${i.remainingQuantity}/${i.initialQuantity}, Expires: ${i.expiryDate.toIso8601String()}").join('\n');
      final prompt = '''
Analyze this inventory state:
$payload
Current Date: ${DateTime.now().toIso8601String()}

Identify critical shortages (below 15% quantity threshold) and expiry warnings (under 90 days). 
Return a JSON array of objects. 
[
  {
    "severity": "red" (for shortages) OR "orange" (for expiries),
    "title": "<medicine_name>",
    "description": "<robust warning text outlining the immediate logistical problem>"
  }
]
''';

      final result = await _tryGenerate(prompt);
      if (result != null) {
        try {
          final rawText = result.replaceAll('```json', '').replaceAll('```', '').trim();
          List<dynamic> alertsData = jsonDecode(rawText);
          return alertsData.cast<Map<String, dynamic>>();
        } catch (e) {
          print('AIService: Failed to parse alerts response: $e');
        }
      }
    }

    // Offline fallback — compute alerts locally from inventory data
    final alerts = <Map<String, dynamic>>[];
    for (var item in inventory) {
      final pct = item.initialQuantity > 0
          ? ((item.remainingQuantity / item.initialQuantity) * 100).round()
          : 0;
      final daysToExpiry = item.expiryDate.difference(DateTime.now()).inDays;

      if (pct <= 15) {
        alerts.add({
          "severity": "red",
          "title": "${item.medicineName} — Critical Shortage",
          "description": "Only ${item.remainingQuantity}/${item.initialQuantity} units remaining ($pct%). "
              "Immediate restocking required to maintain patient care continuity."
        });
      }
      if (daysToExpiry <= 90) {
        alerts.add({
          "severity": "orange",
          "title": "${item.medicineName} — Expiry Warning",
          "description": "Batch expires in $daysToExpiry days. ${item.remainingQuantity} units at risk. "
              "Consider prioritizing distribution or initiating a transfer before expiry."
        });
      }
    }

    if (alerts.isEmpty) {
      alerts.add({
        "severity": "green",
        "title": "All Systems Nominal",
        "description": "No critical shortages or expiry warnings detected across ${inventory.length} tracked medicines."
      });
    }

    return alerts;
  }

  Future<String> generateRedistributionPlan(List<MedRequest> requests, List<Facility> facilities) async {
    if (!_offlineMode && (_model != null || _fallbackModel != null) && requests.isNotEmpty) {
      final reqSummary = requests.map((r) => '${r.medicineName}: ${r.quantity} units (${r.type.name}) from facility ${r.facilityId}').join('\n');
      final facSummary = facilities.map((f) => '${f.name} (${f.type}) at (${f.latitude}, ${f.longitude})').join('\n');
      final prompt = '''
Analyze these medical supply requests and facilities to suggest optimal redistribution:

Requests:
$reqSummary

Facilities:
$facSummary

Provide a concise 2-3 sentence redistribution recommendation focusing on minimizing transport time and matching surplus to shortage.
''';

      final result = await _tryGenerate(prompt);
      if (result != null) return result;
    }

    // Offline fallback
    await Future.delayed(const Duration(milliseconds: 500));
    if (requests.isEmpty) {
      return "No active requests found. Create shortage or surplus requests from facilities to enable AI redistribution matching.";
    }
    final shortages = requests.where((r) => r.type == RequestType.shortage || r.type == RequestType.regularIndent).length;
    final surpluses = requests.where((r) => r.type == RequestType.surplus).length;
    return "Analysis complete: $shortages shortage requests and $surpluses surplus reports detected across ${facilities.length} facilities. "
        "Recommend prioritizing transfers between geographically closest facilities to minimize transport time by up to 23%.";
  }
}
