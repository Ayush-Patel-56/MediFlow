import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../services/ai_service.dart';

class AlertsPage extends ConsumerStatefulWidget {
  final String facilityId;
  const AlertsPage({super.key, required this.facilityId});

  @override
  ConsumerState<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends ConsumerState<AlertsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _diagnosticAlerts = [];
  DateTime? _lastFetchTime;

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    setState(() => _isLoading = true);
    try {
      final inventory = await ref.read(firebaseServiceProvider).getInventoryOnce(widget.facilityId);
      final alerts = await ref.read(aiServiceProvider).generateSmartAlerts(inventory);
      if (mounted) {
        setState(() {
          _diagnosticAlerts = alerts;
          _isLoading = false;
          _lastFetchTime = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _lastFetchTime = DateTime.now();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating alerts: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final redCount = _diagnosticAlerts.where((a) => a['severity'] == 'red').length;
    final orangeCount = _diagnosticAlerts.where((a) => a['severity'] == 'orange').length;
    final lastUpdatedStr = _lastFetchTime != null
        ? 'Last analyzed: ${DateFormat('MMM dd, HH:mm').format(_lastFetchTime!)}'
        : '';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('AI Diagnostics & Alerts', style: TextStyle(fontWeight: FontWeight.bold)),
            if (lastUpdatedStr.isNotEmpty)
              Text(lastUpdatedStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.grey)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: _fetchAlerts,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(width: 16), Text("Gemini AI Analyzing Inventory...")]))
          : ListView(
              padding: const EdgeInsets.all(32),
              children: [
                // Severity Summary Row
                if (_diagnosticAlerts.isNotEmpty) ...[
                  Row(
                    children: [
                      if (redCount > 0) _buildSeverityChip('$redCount Critical', Colors.red),
                      if (redCount > 0 && orangeCount > 0) const SizedBox(width: 12),
                      if (orangeCount > 0) _buildSeverityChip('$orangeCount Warnings', Colors.orange),
                      if (redCount == 0 && orangeCount == 0) _buildSeverityChip('All Clear', Colors.green),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                _buildAlertSection(
                  context,
                  'Active Logistics Diagnostics',
                  Icons.psychology,
                  Colors.blue,
                  _diagnosticAlerts.map((alert) {
                    final isRed = alert['severity'] == 'red';
                    return _buildAlertCard(
                      alert['title'] ?? 'Notice',
                      alert['description'] ?? '',
                      isRed ? Colors.red : Colors.orange,
                    );
                  }).toList(),
                  showEmpty: _diagnosticAlerts.isEmpty,
                ),
                const SizedBox(height: 32),
                _buildAlertSection(
                  context,
                  'AI Redistribution Suggestions',
                  Icons.swap_horiz,
                  Colors.indigo,
                  [
                    _buildAlertCard('Feature Offline', 'Automated redistribution optimization matching will be enabled in a future system pipeline.', Colors.indigo),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSeverityChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(label.contains('Clear') ? Icons.check_circle : Icons.warning_amber, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildAlertSection(BuildContext context, String title, IconData icon, Color color, List<Widget> children, {bool showEmpty = false}) {
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
        if (showEmpty) 
           Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Text("All systems nominal. No critical shortages or dangerous expiries found in current inventory block.", style: TextStyle(color: Colors.green)))
        else
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
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
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
