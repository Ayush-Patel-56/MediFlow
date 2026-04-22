import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/firebase_service.dart';
import '../../services/ai_service.dart';
import '../../models/request.dart';
import '../../models/facility.dart';

class AdminOverview extends ConsumerStatefulWidget {
  const AdminOverview({super.key});

  @override
  ConsumerState<AdminOverview> createState() => _AdminOverviewState();
}

class _AdminOverviewState extends ConsumerState<AdminOverview> {
  List<Facility> _facilities = [];
  bool _isLoading = true;
  bool _isOptimizing = false;
  String? _optimizationResult;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final facs = await ref.read(firebaseServiceProvider).getFacilities();
    if (mounted) {
      setState(() {
        _facilities = facs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Admin views global requests, so facilityId is null
    final requestsStream = ref.watch(firebaseServiceProvider).streamRequests(null);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('CMS Admin Overview', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<MedRequest>>(
        stream: requestsStream,
        builder: (context, snapshot) {
          final requests = snapshot.data ?? [];
          final criticalShortages = requests.where((r) => r.type == RequestType.shortage || r.type == RequestType.regularIndent).length;
          final identifiedSurplus = requests.where((r) => r.type == RequestType.surplus).length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KPI Metrics
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    _buildMetricCard(context, 'Total Facilities', _facilities.length.toString(), Icons.domain, Colors.indigo),
                    _buildMetricCard(context, 'Total Indent Orders', requests.length.toString(), Icons.inventory, Colors.teal),
                    _buildMetricCard(context, 'Active Shortages', criticalShortages.toString(), Icons.warning, Colors.red),
                    _buildMetricCard(context, 'Identified Surplus', identifiedSurplus.toString(), Icons.add_circle, Colors.green),
                  ],
                ),
                const SizedBox(height: 48),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 900;
                    
                    final requestsSection = Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Incoming Indent Requests', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 24),
                          if (requests.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No unfulfilled requests active in CMS.', style: TextStyle(fontStyle: FontStyle.italic)),
                            )
                          else
                            ...requests.take(5).map((req) {
                              final facName = _facilities.firstWhere((f) => f.id == req.facilityId, orElse: () => Facility(id: '', name: 'Unknown', email: '', type: '', region: '', latitude: 0, longitude: 0, createdAt: DateTime.now())).name;
                              final isCrit = req.type == RequestType.shortage;
                              return Column(
                                children: [
                                  _buildRequestItem(facName, '${req.medicineName} (${req.quantity} units)', isCrit ? 'Critical Shortage' : 'Routine Indent', isCrit ? Colors.red : Colors.blue),
                                  const Divider(),
                                ],
                              );
                            }),
                        ],
                      ),
                    );

                    final aiSection = Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.indigo[50]!, Colors.purple[50]!], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.indigo[100]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome, color: Colors.indigo),
                              SizedBox(width: 12),
                              Text('Smart Matching', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.indigo)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text('Gemini AI can analyze current stock levels across all facilities and instantly suggest redistribution paths from surplus clinics to those in shortage.', style: TextStyle(color: Colors.indigo[900], height: 1.5)),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              icon: _isOptimizing
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.flash_on),
                              label: Text(_isOptimizing ? 'Analyzing...' : 'Run Global Optimization'),
                              style: FilledButton.styleFrom(backgroundColor: Colors.indigo, padding: const EdgeInsets.symmetric(vertical: 20)),
                              onPressed: _isOptimizing ? null : () async {
                                setState(() {
                                  _isOptimizing = true;
                                  _optimizationResult = null;
                                });
                                final result = await ref.read(aiServiceProvider).generateRedistributionPlan(requests, _facilities);
                                if (mounted) {
                                  setState(() {
                                    _isOptimizing = false;
                                    _optimizationResult = result;
                                  });
                                }
                              },
                            ),
                          ),
                          if (_optimizationResult != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.indigo.withValues(alpha: 0.4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.check_circle, color: Colors.indigo, size: 18),
                                    const SizedBox(width: 8),
                                    const Text('AI Redistribution Plan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                                  ]),
                                  const SizedBox(height: 8),
                                  Text(_optimizationResult!, style: TextStyle(color: Colors.indigo[900], fontSize: 13, height: 1.5)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: requestsSection),
                          const SizedBox(width: 32),
                          Expanded(flex: 1, child: aiSection),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          requestsSection,
                          const SizedBox(height: 32),
                          aiSection,
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRequestItem(String facility, String items, String status, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(facility, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(items, style: TextStyle(color: Colors.grey[600])),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
