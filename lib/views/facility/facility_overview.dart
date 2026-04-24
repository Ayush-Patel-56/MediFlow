import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/inventory_item.dart';
import '../../services/firebase_service.dart';
import '../../main.dart';

class FacilityOverview extends ConsumerWidget {
  final String facilityId;
  const FacilityOverview({super.key, required this.facilityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryStream = ref.watch(firebaseServiceProvider).streamInventory(facilityId);

    return StreamBuilder<List<InventoryItem>>(
      stream: inventoryStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final inventory = snapshot.data ?? [];
        final expiringSoon = inventory.where((i) => i.expiryDate.difference(DateTime.now()).inDays < 90).length;
        final lowStock = inventory.where((i) => i.remainingQuantity < (i.initialQuantity * 0.15)).length;

        String lastDelivery = 'No data';
        if (inventory.isNotEmpty) {
          final sorted = [...inventory]..sort((a, b) => b.arrivalDate.compareTo(a.arrivalDate));
          final daysAgo = DateTime.now().difference(sorted.first.arrivalDate).inDays;
          if (daysAgo == 0) lastDelivery = 'Today';
          else if (daysAgo == 1) lastDelivery = 'Yesterday';
          else lastDelivery = '$daysAgo Days Ago';
        }

        return Scaffold(
          backgroundColor: MediColors.bg,
          appBar: AppBar(
            title: const Text('Dashboard'),
            actions: [
              // Live Alert Bell
              PopupMenuButton<String>(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined, color: MediColors.textSecondary),
                    if (lowStock + expiringSoon > 0)
                      Positioned(
                        top: -2, right: -2,
                        child: Container(
                          width: 16, height: 16,
                          decoration: const BoxDecoration(color: MediColors.error, shape: BoxShape.circle),
                          child: Center(child: Text('${lowStock + expiringSoon}', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700))),
                        ),
                      ),
                  ],
                ),
                tooltip: 'Alerts',
                itemBuilder: (context) {
                  final alerts = <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(value: 'h', enabled: false, child: Text('Live Alerts', style: TextStyle(fontWeight: FontWeight.w700, color: MediColors.textPrimary))),
                    const PopupMenuDivider(),
                  ];
                  final lowItems = inventory.where((i) => i.remainingQuantity < (i.initialQuantity * 0.15)).toList();
                  final expiringItems = inventory.where((i) => i.expiryDate.difference(DateTime.now()).inDays < 90).toList();
                  for (var item in lowItems) {
                    alerts.add(PopupMenuItem<String>(value: 'l_${item.medicineName}', child: ListTile(
                      leading: const Icon(Icons.warning_rounded, color: MediColors.error, size: 20),
                      title: Text('${item.medicineName} critically low', style: const TextStyle(fontSize: 13, color: MediColors.textPrimary)),
                      subtitle: Text('${item.remainingQuantity} units left', style: const TextStyle(fontSize: 11, color: MediColors.textMuted)),
                      dense: true, contentPadding: EdgeInsets.zero,
                    )));
                  }
                  for (var item in expiringItems) {
                    final d = item.expiryDate.difference(DateTime.now()).inDays;
                    alerts.add(PopupMenuItem<String>(value: 'e_${item.medicineName}', child: ListTile(
                      leading: const Icon(Icons.schedule_rounded, color: MediColors.warning, size: 20),
                      title: Text('${item.medicineName} expires in $d d', style: const TextStyle(fontSize: 13, color: MediColors.textPrimary)),
                      dense: true, contentPadding: EdgeInsets.zero,
                    )));
                  }
                  if (lowItems.isEmpty && expiringItems.isEmpty) {
                    alerts.add(const PopupMenuItem<String>(value: 'ok', enabled: false, child: ListTile(
                      leading: Icon(Icons.check_circle_rounded, color: MediColors.success, size: 20),
                      title: Text('All systems healthy', style: TextStyle(fontSize: 13, color: MediColors.textSecondary)),
                      dense: true, contentPadding: EdgeInsets.zero,
                    )));
                  }
                  return alerts;
                },
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                child: const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: CircleAvatar(radius: 18, backgroundColor: MediColors.surfaceLight, child: Icon(Icons.person_rounded, color: MediColors.textSecondary, size: 20)),
                ),
                itemBuilder: (c) => [
                  const PopupMenuItem(value: 'out', child: ListTile(leading: Icon(Icons.logout_rounded, color: MediColors.error), title: Text('Sign Out'), dense: true, contentPadding: EdgeInsets.zero)),
                ],
                onSelected: (v) async {
                  if (v == 'out') { context.go('/'); await FirebaseAuth.instance.signOut(); }
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting
                Text('Facility Dashboard', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: MediColors.textPrimary)),
                const SizedBox(height: 4),
                Text('Real-time inventory monitoring and insights', style: const TextStyle(color: MediColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 28),

                // KPI Cards
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    _buildKpiCard('Total Medicines', '${inventory.length}', Icons.medication_rounded, MediColors.info, const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF1E293B)])),
                    _buildKpiCard('Expiring Soon', '$expiringSoon', Icons.hourglass_bottom_rounded, MediColors.warning, const LinearGradient(colors: [Color(0xFF3D2E0A), Color(0xFF1E293B)])),
                    _buildKpiCard('Low Stock', '$lowStock', Icons.trending_down_rounded, MediColors.error, const LinearGradient(colors: [Color(0xFF3D1519), Color(0xFF1E293B)])),
                    _buildKpiCard('Last Delivery', lastDelivery, Icons.local_shipping_rounded, MediColors.success, const LinearGradient(colors: [Color(0xFF0A3D2E), Color(0xFF1E293B)])),
                  ],
                ),
                const SizedBox(height: 36),
                _buildInventoryTable(context, inventory),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color accent, LinearGradient bg) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(height: 18),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: accent)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 13, color: MediColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildInventoryTable(BuildContext context, List<InventoryItem> inventory) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Inventory Status', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: MediColors.textPrimary)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: MediColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MediColors.border),
          ),
          child: inventory.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(48),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: MediColors.textMuted),
                      const SizedBox(height: 12),
                      Text('No inventory items yet', style: TextStyle(color: MediColors.textMuted)),
                    ]),
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: DataTable(
                    columnSpacing: 28,
                    columns: const [
                      DataColumn(label: Text('Medicine')),
                      DataColumn(label: Text('Quantity')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Expiry')),
                    ],
                    rows: inventory.map((item) {
                      final pct = item.initialQuantity > 0 ? (item.remainingQuantity / item.initialQuantity) : 1.0;
                      final daysToExpiry = item.expiryDate.difference(DateTime.now()).inDays;
                      Color statusColor;
                      String statusText;
                      if (pct <= 0.15) { statusColor = MediColors.error; statusText = 'Critical'; }
                      else if (pct <= 0.35) { statusColor = MediColors.warning; statusText = 'Low'; }
                      else { statusColor = MediColors.success; statusText = 'Healthy'; }

                      return DataRow(cells: [
                        DataCell(Row(children: [
                          Container(width: 4, height: 32, decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(4))),
                          const SizedBox(width: 12),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(item.medicineName, style: const TextStyle(fontWeight: FontWeight.w600, color: MediColors.textPrimary)),
                            Text(item.batchId, style: const TextStyle(fontSize: 11, color: MediColors.textMuted)),
                          ]),
                        ])),
                        DataCell(Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item.remainingQuantity} / ${item.initialQuantity}', style: const TextStyle(color: MediColors.textPrimary, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 100,
                              child: LinearProgressIndicator(
                                value: pct,
                                backgroundColor: MediColors.surfaceLight,
                                color: statusColor,
                                minHeight: 4,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        )),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                          child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                        )),
                        DataCell(Text(
                          daysToExpiry > 365 ? '${(daysToExpiry / 365).toStringAsFixed(1)} yr' : '$daysToExpiry days',
                          style: TextStyle(color: daysToExpiry < 90 ? MediColors.warning : MediColors.textSecondary),
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }
}
