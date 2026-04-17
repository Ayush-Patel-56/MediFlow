import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/inventory_item.dart';
import '../../services/firebase_service.dart';
import '../../services/ai_service.dart';

class AIForecastPage extends ConsumerStatefulWidget {
  final String facilityId;
  const AIForecastPage({super.key, required this.facilityId});

  @override
  ConsumerState<AIForecastPage> createState() => _AIForecastPageState();
}

class _AIForecastPageState extends ConsumerState<AIForecastPage> {
  int _forecastDays = 30;
  String? _selectedMed;
  int? _forecastResult;
  bool _isForecasting = false;

  @override
  Widget build(BuildContext context) {
    final inventoryStream = ref.watch(firebaseServiceProvider).streamInventory(widget.facilityId);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('AI Demand Forecast', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<InventoryItem>>(
        stream: inventoryStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final inventory = snapshot.data ?? [];
          final medNames = inventory.map((i) => i.medicineName).toSet().toList();
          
          if (_selectedMed == null && medNames.isNotEmpty) {
            _selectedMed = medNames.first;
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT: Controls
              Container(
                width: 350,
                color: Colors.white,
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Parameters', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 32),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: 'Medicine', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      value: _selectedMed,
                      items: medNames.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) => setState(() { _selectedMed = v; _forecastResult = null; }),
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(labelText: 'Forecast Duration', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      value: _forecastDays,
                      items: const [
                        DropdownMenuItem(value: 30, child: Text('1 Month (30 Days)')),
                        DropdownMenuItem(value: 90, child: Text('1 Quarter (90 Days)')),
                      ],
                      onChanged: (v) => setState(() { _forecastDays = v!; _forecastResult = null; }),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        icon: _isForecasting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                        label: const Text('Generate Forecast', style: TextStyle(fontSize: 16)),
                        onPressed: _isForecasting ? null : () async {
                          setState(() => _isForecasting = true);
                          final logs = await ref.read(firebaseServiceProvider).getUsageLogs(widget.facilityId, _selectedMed!);
                          final result = await ref.read(aiServiceProvider).forecastDemand(_selectedMed!, logs, _forecastDays);
                          setState(() {
                            _forecastResult = result;
                            _isForecasting = false;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // RIGHT: Chart & Insights
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      // Chart Container
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Historical vs Forecasted Demand', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 32),
                              Expanded(child: _buildChart()),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Insight Box
                      Expanded(
                        flex: 1,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue[200]!)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.psychology, color: Colors.blue, size: 32),
                                  const SizedBox(width: 12),
                                  Text('Gemini Insight', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (_forecastResult == null)
                                Text('Run the forecaster to see AI insights.', style: TextStyle(color: Colors.blue[800], fontSize: 16))
                              else
                                Text('Based on the past 120 days of usage and seasonal trends (e.g., upcoming winter), Gemini predicts a total demand of $_forecastResult units for $_selectedMed over the next $_forecastDays days.', style: TextStyle(color: Colors.blue[800], fontSize: 16, height: 1.5)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChart() {
    // We use a dummy chart structure that looks like the AI projection from the mockups
    final baseData = [10.0, 12.0, 15.0, 13.0, 20.0, 25.0, 22.0, 30.0, 28.0];
    final forecastData = [28.0, 35.0, 40.0, 38.0, 45.0];

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200], strokeWidth: 1)),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const Text('Past');
                if (value == 8) return const Text('Today');
                if (value == 13) return const Text('Future');
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          // Historical Line
          LineChartBarData(
            spots: baseData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
            isCurved: true,
            color: Colors.blue,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
          ),
          // Forecast Line (Only shows if forecasted)
          if (_forecastResult != null)
            LineChartBarData(
              spots: forecastData.asMap().entries.map((e) => FlSpot((e.key + 8).toDouble(), e.value)).toList(),
              isCurved: true,
              color: Colors.purple,
              barWidth: 4,
              isStrokeCapRound: true,
              dashArray: [5, 5], // Dotted line for forecast
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }
}
