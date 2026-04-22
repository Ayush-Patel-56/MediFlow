import 'package:flutter/material.dart';

class AlertsPage extends StatelessWidget {
  final String facilityId;
  const AlertsPage({super.key, required this.facilityId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Alerts & Suggestions', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          _buildAlertSection(
            context,
            'Low Stock Alerts',
            Icons.warning_amber_rounded,
            Colors.red,
            [
              _buildAlertCard('Paracetamol', 'Current stock is 120 units (Below 15% threshold). Will run out in 5 days based on current usage.', Colors.red),
            ],
          ),
          const SizedBox(height: 32),
          _buildAlertSection(
            context,
            'Expiry Warnings',
            Icons.timer,
            Colors.orange,
            [
              _buildAlertCard('Amoxicillin (Batch B-842)', 'Expires in 45 days. Suggest initiating return or priority redistribution.', Colors.orange),
              _buildAlertCard('Ibuprofen (Batch B-112)', 'Expires in 80 days.', Colors.orange),
            ],
          ),
          const SizedBox(height: 32),
          _buildAlertSection(
            context,
            'AI Redistribution Suggestions',
            Icons.swap_horiz,
            Colors.blue,
            [
              _buildAlertCard('Surplus Cetirizine', 'You have a 400 unit surplus. Facility B is experiencing a shortage. Tap to offer redistribution.', Colors.blue, action: 'Offer Transfer'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertSection(BuildContext context, String title, IconData icon, Color color, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildAlertCard(String title, String message, Color color, {String? action}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.info_outline, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(color: Colors.grey[700])),
                if (action != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color)),
                    onPressed: () {},
                    child: Text(action),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}
