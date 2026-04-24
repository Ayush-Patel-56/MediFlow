import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/firebase_service.dart';
import '../../services/ai_service.dart';
import '../../models/inventory_item.dart';
import '../../main.dart';

class AlertsPage extends ConsumerStatefulWidget {
  final String facilityId;
  const AlertsPage({super.key, required this.facilityId});

  @override
  ConsumerState<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends ConsumerState<AlertsPage> {
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      final inventory = await ref.read(firebaseServiceProvider).getInventoryOnce(widget.facilityId);
      final alerts = await ref.read(aiServiceProvider).generateSmartAlerts(inventory);
      if (mounted) setState(() { _alerts = alerts; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MediColors.bg,
      appBar: AppBar(
        title: const Text('Smart Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: MediColors.textSecondary),
            onPressed: _loadAlerts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(28),
              itemCount: _alerts.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Alert Center', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: MediColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('${_alerts.length} active alerts detected', style: const TextStyle(color: MediColors.textSecondary)),
                    ]),
                  );
                }
                final alert = _alerts[index - 1];
                final severity = alert['severity'] ?? 'red';
                final color = severity == 'red' ? MediColors.error : severity == 'orange' ? MediColors.warning : MediColors.success;
                final icon = severity == 'red' ? Icons.error_rounded : severity == 'orange' ? Icons.warning_rounded : Icons.check_circle_rounded;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: MediColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                        child: Icon(icon, color: color, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(alert['title'] ?? '', style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 15)),
                          const SizedBox(height: 6),
                          Text(alert['description'] ?? '', style: const TextStyle(color: MediColors.textSecondary, height: 1.5, fontSize: 13)),
                        ]),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
