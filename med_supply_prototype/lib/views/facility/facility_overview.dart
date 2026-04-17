import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/inventory_item.dart';
import '../../services/firebase_service.dart';
import 'package:intl/intl.dart';

class FacilityOverview extends ConsumerWidget {
  final String facilityId;
  const FacilityOverview({super.key, required this.facilityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryStream = ref.watch(firebaseServiceProvider).streamInventory(facilityId);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Facility Overview', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: CircleAvatar(child: Icon(Icons.person)),
          ),
        ],
      ),
      body: StreamBuilder<List<InventoryItem>>(
        stream: inventoryStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final inventory = snapshot.data ?? [];
          final expiringSoon = inventory.where((i) => i.expiryDate.difference(DateTime.now()).inDays < 90).length;
          final lowStock = inventory.where((i) => i.currentQuantity < (i.initialQuantity * 0.15)).length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KPI Cards
                Row(
                  children: [
                    Expanded(child: _buildKpiCard(context, 'Total Medicines', inventory.length.toString(), Icons.medication, Colors.blue)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildKpiCard(context, 'Expiring Soon', expiringSoon.toString(), Icons.warning, Colors.orange)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildKpiCard(context, 'Low Stock Alerts', lowStock.toString(), Icons.error, Colors.red)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildKpiCard(context, 'Last Delivery', '2 Days Ago', Icons.local_shipping, Colors.green)),
                  ],
                ),
                const SizedBox(height: 48),
                Text('Current Inventory', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                _buildInventoryTable(context, inventory),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKpiCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryTable(BuildContext context, List<InventoryItem> inventory) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: DataTable(
        headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
        columns: const [
          DataColumn(label: Text('Medicine Name')),
          DataColumn(label: Text('Batch ID')),
          DataColumn(label: Text('Units Available')),
          DataColumn(label: Text('Expiry Date')),
          DataColumn(label: Text('Arrival Date')),
          DataColumn(label: Text('Status')),
        ],
        rows: inventory.map((item) {
          final isLow = item.currentQuantity < (item.initialQuantity * 0.15);
          final isExpiring = item.expiryDate.difference(DateTime.now()).inDays < 90;
          
          Widget statusBadge;
          if (isLow) statusBadge = _buildBadge('Low Stock', Colors.red);
          else if (isExpiring) statusBadge = _buildBadge('Expiring Soon', Colors.orange);
          else statusBadge = _buildBadge('Healthy', Colors.green);

          return DataRow(cells: [
            DataCell(Text(item.medicineName, style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text(item.batchId, style: TextStyle(color: Colors.grey[600]))),
            DataCell(Text('${item.currentQuantity} ${item.unit}')),
            DataCell(Text(DateFormat('MMM dd, yyyy').format(item.expiryDate))),
            DataCell(Text(DateFormat('MMM dd, yyyy').format(item.arrivalDate))),
            DataCell(statusBadge),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
