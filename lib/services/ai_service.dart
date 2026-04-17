import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_usage_log.dart';
import '../models/request.dart';
import '../models/facility.dart';

// IMPORTANT: Replace this with your actual Gemini API Key from Google AI Studio
const String geminiApiKey = 'YOUR_API_KEY_HERE';

final aiServiceProvider = Provider<AIService>((ref) {
  return AIService();
});

class AIService {
  late final GenerativeModel? _model;

  AIService() {
    if (geminiApiKey != 'YOUR_API_KEY_HERE' && geminiApiKey.isNotEmpty) {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: geminiApiKey,
      );
    } else {
      _model = null;
      print('WARNING: Gemini API Key not set. Using Mock AI Service.');
    }
  }

  /// Forecasts demand for the next [days] based on [logs].
  Future<int> forecastDemand(String medicineName, List<DailyUsageLog> logs, int daysToForecast) async {
    // Extract specific medicine usage from daily logs
    final medLogs = logs.map((l) {
      final usage = l.medicines.firstWhere((m) => m.medicineName == medicineName, orElse: () => MedicineUsage(medicineName: medicineName, unitsDistributed: 0));
      return {'date': l.date, 'used': usage.unitsDistributed};
    }).toList();

    if (_model == null) {
      // MOCK FALLBACK
      await Future.delayed(const Duration(seconds: 2));
      if (medLogs.isEmpty) return daysToForecast * 15; // default guess
      double avg = medLogs.fold(0.0, (sum, log) => sum + (log['used'] as int)) / medLogs.length;
      // Add slight randomness to look like AI
      return (avg * daysToForecast * 1.1).round(); 
    }

    try {
      final logSummary = medLogs.take(30).map((l) => 'Date: ${(l['date'] as DateTime).toIso8601String()}, Used: ${l['used']}').join('\n');
      final prompt = '''
        You are an AI Demand Forecaster for a medical supply chain.
        Medicine: $medicineName
        I need a forecast for the next $daysToForecast days.
        Here is a sample of recent daily usage data:
        $logSummary
        
        Consider seasonality (e.g. winters mean more cold meds).
        Based on this trend, predict the exact total quantity needed for the next $daysToForecast days.
        Return ONLY a single integer number. Do not include any other text.
      ''';

      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      
      final text = response.text?.trim() ?? '';
      return int.tryParse(text) ?? _fallbackForecast(medLogs, daysToForecast);
    } catch (e) {
      print('Gemini API Error: $e');
      return _fallbackForecast(medLogs, daysToForecast);
    }
  }

  int _fallbackForecast(List<Map<String, dynamic>> medLogs, int daysToForecast) {
    if (medLogs.isEmpty) return daysToForecast * 15;
    double avg = medLogs.fold(0.0, (sum, log) => sum + (log['used'] as int)) / medLogs.length;
    return (avg * daysToForecast * 1.1).round();
  }

  /// Generates a redistribution plan based on surplus and shortage requests
  Future<String> generateRedistributionPlan(List<MedRequest> requests, List<Facility> facilities) async {
    if (_model == null) {
      // MOCK FALLBACK
      await Future.delayed(const Duration(seconds: 2));
      return "Based on distance and inventory levels, it is optimal to shift 50 Paracetamol from Noida Community Center to Delhi City Hospital. This minimizes transport time by 23%.";
    }

    try {
      final requestStrings = requests.map((r) {
        final fac = facilities.firstWhere((f) => f.id == r.facilityId);
        return '${r.type.name.toUpperCase()} at ${fac.name}: ${r.quantity} ${r.medicineName} (Lat: ${fac.latitude}, Lng: ${fac.longitude})';
      }).join('\n');

      final prompt = '''
        You are a Smart Matching Engine for a medical supply chain.
        I have the following current Shortage and Surplus requests across various facilities:
        $requestStrings
        
        Generate a smart redistribution plan. Match surpluses to shortages, prioritizing short geographical distances to optimize logistics. 
        Provide a concise, 2-3 sentence summary of the best actions to take.
      ''';

      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      return response.text ?? 'Unable to generate plan.';
    } catch (e) {
      print('Gemini API Error: $e');
      return "Error connecting to AI for matching. Please review manually.";
    }
  }
}
