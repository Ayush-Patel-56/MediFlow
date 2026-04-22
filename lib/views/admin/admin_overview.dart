import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/firebase_service.dart';
import '../../models/request.dart';
import '../../models/facility.dart';

class AdminOverview extends ConsumerStatefulWidget {
  const AdminOverview({super.key});

  @override
  ConsumerState<AdminOverview> createState() => _AdminOverviewState();
}

class _AdminOverviewState extends ConsumerState<AdminOverview> {
  List<Facility> _facilities = [];

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  Future<void> _loadFacilities() async {
    final facs = await ref.read(firebaseServiceProvider).getFacilities();
    if (mounted) setState(() => _facilities = facs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('CMS Admin Overview', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Metrics
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                _buildMetricCard(context, 'Total Facilities', '14', Icons.domain, Colors.indigo),
                _buildMetricCard(context, 'Total Stock', '2.4M', Icons.inventory, Colors.teal),
                _buildMetricCard(context, 'Active Shortages', '3', Icons.warning, Colors.red),
                _buildMetricCard(context, 'Identified Surplus', '5', Icons.add_circle, Colors.green),
              ],
            ),
            const SizedBox(height: 48),

            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                
                final requests = Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Incoming Indent Requests', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      StreamBuilder<List<MedRequest>>(
                        stream: ref.watch(firebaseServiceProvider).streamRequests(null),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
                          final requestsList = snapshot.data ?? [];
                          if (requestsList.isEmpty) return const Text('No incoming requests currently.');
                          
                          return Column(
                            children: requestsList.map((req) {
                              final facName = _facilities.firstWhere(
                                (f) => f.id == req.facilityId, 
                                orElse: () => Facility(id: '', name: 'Unknown Facility', type: 'clinic', email: '', region: '', latitude: 0, longitude: 0, createdAt: DateTime.now())
                              ).name;
                              
                              final isShortage = req.type == RequestType.shortage;
                              final color = isShortage ? Colors.red : Colors.green;
                              final statusText = isShortage ? 'Shortage' : 'Surplus';
                              
                              return Column(
                                children: [
                                  _buildRequestItem(facName, '${req.medicineName} (${req.quantity} units)', statusText, color),
                                  const Divider(),
                                ],
                              );
                            }).toList(),
                          );
                        },
                      ),
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
                          icon: const Icon(Icons.flash_on),
                          label: const Text('Run Global Optimization'),
                          style: FilledButton.styleFrom(backgroundColor: Colors.indigo, padding: const EdgeInsets.symmetric(vertical: 20)),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Optimization complete! See Routing tab.')));
                          },
                        ),
                      ),
                    ],
                  ),
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: requests),
                      const SizedBox(width: 32),
                      Expanded(flex: 1, child: aiSection),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      requests,
                      const SizedBox(height: 32),
                      aiSection,
                    ],
                  );
                }
              },
            ),
          ],
        ),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
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
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
