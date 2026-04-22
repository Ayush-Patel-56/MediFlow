import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/inventory_item.dart';
import '../../models/daily_usage_log.dart';
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
  Map<String, dynamic>? _forecastResult;
  bool _isForecasting = false;

  // Real historical usage data for the selected medicine
  List<double> _historicalData = [];
  bool _isLoadingHistory = false;

  Future<void> _loadHistoricalData(String medicineName) async {
    setState(() {
      _isLoadingHistory = true;
      _historicalData = [];
      _forecastResult = null;
    });
    try {
      final logs = await ref.read(firebaseServiceProvider).getRecentLogs(widget.facilityId, days: 30);
      // Sort ascending by date so the chart reads left-to-right
      final sorted = [...logs]..sort((a, b) => a.date.compareTo(b.date));
      final data = sorted.map((log) {
        final usage = log.medicines.firstWhere(
          (m) => m.medicineName == medicineName,
          orElse: () => MedicineUsage(medicineName: medicineName, unitsDistributed: 0),
        );
        return usage.unitsDistributed.toDouble();
      }).toList();

      if (mounted) {
        setState(() {
          _historicalData = data;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

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
            // Load initial data without calling setState inside build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadHistoricalData(_selectedMed!);
            });
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 1100;
              
              final controls = Container(
                width: isWide ? 350 : double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Parameters', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 32),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: 'Medicine', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      value: _selectedMed,
                      items: medNames.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) {
                        setState(() { _selectedMed = v; _forecastResult = null; });
                        if (v != null) _loadHistoricalData(v);
                      },
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
                          final logs = await ref.read(firebaseServiceProvider).getRecentLogs(widget.facilityId);
                          final result = await ref.read(aiServiceProvider).forecastDemand(_selectedMed!, logs, _forecastDays);
                          setState(() {
                            _forecastResult = result;
                            _isForecasting = false;
                          });
                        },
                      ),
                    ),
                    if (_historicalData.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.history, color: Colors.teal, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text('${_historicalData.length} days of usage data loaded', style: const TextStyle(color: Colors.teal, fontSize: 13))),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );

              final mainContent = Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    // Chart Container
                    Container(
                      height: 400,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Historical vs Forecasted Demand', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                              const Spacer(),
                              // Legend
                              Row(children: [Container(width: 12, height: 12, color: Colors.blue), const SizedBox(width: 6), const Text('Historical', style: TextStyle(fontSize: 12))]),
                              const SizedBox(width: 16),
                              if (_forecastResult != null)
                                Row(children: [Container(width: 12, height: 12, color: Colors.purple), const SizedBox(width: 6), const Text('Forecast', style: TextStyle(fontSize: 12))]),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _isLoadingHistory
                                ? const Center(child: CircularProgressIndicator())
                                : _buildChart(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Insight Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue[200]!)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                            Text('Select a medicine and run the forecaster to see AI insights.', style: TextStyle(color: Colors.blue[800], fontSize: 16))
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Prediction: ${_forecastResult!['prediction']} units ($_forecastDays days)', style: TextStyle(color: Colors.blue[900], fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('${_forecastResult!['reasoning']}', style: TextStyle(color: Colors.blue[800], fontSize: 16, height: 1.5)),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    controls,
                    Expanded(child: SingleChildScrollView(child: mainContent)),
                  ],
                );
              } else {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      controls,
                      mainContent,
                    ],
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildChart() {
    // Use real historical data if available, otherwise show a placeholder message
    final historicalSpots = _historicalData.isNotEmpty
        ? _historicalData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList()
        : <FlSpot>[FlSpot(0, 0)];

    // Forecast: draw a projected line from last historical point to predicted total/average
    List<FlSpot> forecastSpots = [];
    if (_forecastResult != null && _historicalData.isNotEmpty) {
      final lastX = _historicalData.length - 1.0;
      final lastY = _historicalData.last;
      // The AI prediction is a total; derive a per-day average for projection end point
      final predTotal = (_forecastResult!['prediction'] as num).toDouble();
      final projectedEndY = predTotal / _forecastDays;
      forecastSpots = [
        FlSpot(lastX, lastY),
        FlSpot(lastX + (_forecastDays / 3.0), projectedEndY * 0.8),
        FlSpot(lastX + (_forecastDays / 1.5), projectedEndY),
      ];
    }

    final maxY = [
      if (_historicalData.isNotEmpty) _historicalData.reduce((a, b) => a > b ? a : b),
      if (forecastSpots.isNotEmpty) forecastSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b),
      1.0,
    ].reduce((a, b) => a > b ? a : b) * 1.2;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withValues(alpha: 0.15), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (_historicalData.isEmpty) return const Text('');
                if (idx == 0) return const Text('D-30', style: TextStyle(fontSize: 10, color: Colors.grey));
                if (idx == _historicalData.length - 1) return const Text('Today', style: TextStyle(fontSize: 10, color: Colors.grey));
                if (_forecastResult != null && idx == (_historicalData.length - 1 + _forecastDays ~/ 1.5)) {
                  return const Text('Proj.', style: TextStyle(fontSize: 10, color: Colors.purple));
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          // Historical Line — real Firestore data
          LineChartBarData(
            spots: historicalSpots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.blue.withValues(alpha: 0.08)),
          ),
          // Forecast projection line
          if (forecastSpots.isNotEmpty)
            LineChartBarData(
              spots: forecastSpots,
              isCurved: true,
              color: Colors.purple,
              barWidth: 3,
              isStrokeCapRound: true,
              dashArray: [6, 4],
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }
}
