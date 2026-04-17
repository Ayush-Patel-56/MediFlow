import 'package:flutter/material.dart';

class AdminOverview extends StatelessWidget {
  const AdminOverview({super.key});

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
            Row(
              children: [
                Expanded(child: _buildMetricCard(context, 'Total Facilities', '14', Icons.domain, Colors.indigo)),
                const SizedBox(width: 24),
                Expanded(child: _buildMetricCard(context, 'Total Stock', '2.4M', Icons.inventory, Colors.teal)),
                const SizedBox(width: 24),
                Expanded(child: _buildMetricCard(context, 'Active Shortages', '3', Icons.warning, Colors.red)),
                const SizedBox(width: 24),
                Expanded(child: _buildMetricCard(context, 'Identified Surplus', '5', Icons.add_circle, Colors.green)),
              ],
            ),
            const SizedBox(height: 48),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Incoming Requests
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Incoming Indent Requests', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        _buildRequestItem('Facility A', 'Paracetamol (500 units)', 'Critical Shortage', Colors.red),
                        const Divider(),
                        _buildRequestItem('Facility C', 'Amoxicillin (200 units)', 'Routine Indent', Colors.blue),
                        const Divider(),
                        _buildRequestItem('Facility D', 'Ibuprofen (100 units)', 'Routine Indent', Colors.blue),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 32),

                // AI Optimization
                Expanded(
                  flex: 1,
                  child: Container(
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
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
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
