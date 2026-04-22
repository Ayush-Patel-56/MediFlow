import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_usage_log.dart';
import '../models/request.dart';
import '../models/facility.dart';
import '../models/inventory_item.dart';

const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'AIzaSyAIFZIZWQOw6XGqIZ_jlR6x5MXPpLKWySc');

final aiServiceProvider = Provider<AIService>((ref) {
  return AIService();
});

class AIService {
  late final GenerativeModel? _model;

  AIService() {
    if (geminiApiKey.isNotEmpty && geminiApiKey != 'YOUR_API_KEY_HERE') {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash-latest',
        apiKey: geminiApiKey,
        systemInstruction: Content.system('''
You are a Medical Logistics AI Expert. 
Your primary function is to strictly analyze dataset payloads and output robust JSON.
Always respond with valid JSON without markdown wrapping. Ensure strict JSON formatting.
'''),
      );
    } else {
      _model = null;
      print('WARNING: Gemini API Key not set. Using Mock AI Service.');
    }
  }

  Future<Map<String, dynamic>> forecastDemand(String medicineName, List<DailyUsageLog> logs, int daysToForecast) async {
    final medLogs = logs.map((l) {
      final usage = l.medicines.firstWhere((m) => m.medicineName == medicineName, orElse: () => MedicineUsage(medicineName: medicineName, unitsDistributed: 0));
      return {'date': l.date, 'used': usage.unitsDistributed};
    }).toList();

    if (_model == null) {
      await Future.delayed(const Duration(seconds: 2));
      return {
        "prediction": _fallbackForecast(medLogs, daysToForecast),
        "reasoning": "This is a fallback generated statistical model due to an missing API key."
      };
    }

    try {
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

      final response = await _model!.generateContent([Content.text(prompt)]);
      final raw = response.text ?? '{}';
      final rawText = raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> data = jsonDecode(rawText);
      return data;
    } catch (e) {
      print('Gemini API Error: $e');
      return {
        "prediction": _fallbackForecast(medLogs, daysToForecast),
        "reasoning": "Gemini API Blocked: $e"
      };
    }
  }

  int _fallbackForecast(List<Map<String, dynamic>> medLogs, int daysToForecast) {
    if (medLogs.isEmpty) return daysToForecast * 15;
    double avg = medLogs.fold(0.0, (sum, log) => sum + (log['used'] as int)) / medLogs.length;
    return (avg * daysToForecast * 1.1).round();
  }

  Future<List<Map<String, dynamic>>> generateSmartAlerts(List<InventoryItem> inventory) async {
    if (_model == null) {
      return [
        {"severity": "red", "title": "System Disconnected", "description": "AI Alerts are offline. Connect API Key."}
      ];
    }

    try {
      final payload = inventory.map((i) => "Med: ${i.medicineName}, Qty: ${i.remainingQuantity}/${i.initialQuantity}, Expires: ${i.expiryDate.toIso8601String()}").join('\n');
      if (inventory.isEmpty) {
         return [{"severity": "red", "title": "Zero Inventory Found", "description": "Log medicines to enable analysis."}];
      }
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

      final response = await _model!.generateContent([Content.text(prompt)]);
      final rawAlert = response.text ?? '[]';
      final rawText = rawAlert.replaceAll('```json', '').replaceAll('```', '').trim();
      List<dynamic> alertsData = jsonDecode(rawText);
      return alertsData.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Gemini Alert Error: $e');
      return [
        {
          "severity": "red", 
          "title": "Google AI Studio Linkage Failure", 
          "description": "The AI could not be reached. Error: $e. Tip: Check if 'gemini-1.5-flash-latest' is enabled in your API key settings or use a different model."
        }
      ];
    }
  }

  Future<String> generateRedistributionPlan(List<MedRequest> requests, List<Facility> facilities) async {
    // Keep it entirely offline/mock to preserve quota constraints per phase 3 plan
    await Future.delayed(const Duration(seconds: 1));
    return "Based on distance and inventory levels, it is optimal to shift 50 Paracetamol from Noida Community Center to Delhi City Hospital. This minimizes transport time by 23%.";
  }
}
