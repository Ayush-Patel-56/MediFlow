import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import '../../services/firebase_service.dart';
import '../../models/request.dart';
import '../../main.dart';

class IndentCreationPage extends ConsumerStatefulWidget {
  final String facilityId;
  const IndentCreationPage({super.key, required this.facilityId});

  @override
  ConsumerState<IndentCreationPage> createState() => _IndentCreationPageState();
}

class _IndentCreationPageState extends ConsumerState<IndentCreationPage> {
  final List<Map<String, dynamic>> _indentItems = [];
  bool _isSubmitting = false;
  String? _csvStatus;

  Future<void> _pickAndParseCSV() async {
    try {
      final uploadInput = html.FileUploadInputElement()..accept = '.csv,.txt';
      uploadInput.click();
      await uploadInput.onChange.first;
      if (uploadInput.files == null || uploadInput.files!.isEmpty) return;
      final file = uploadInput.files!.first;
      final reader = html.FileReader();
      reader.readAsText(file);
      await reader.onLoad.first;
      final csvString = reader.result as String;
      final rows = const CsvDecoder().convert(csvString);
      if (rows.isEmpty) return;
      int startRow = 0;
      final firstCell = rows[0][0].toString().toLowerCase().trim();
      if (firstCell.contains('medicine') || firstCell.contains('name') || firstCell.contains('drug')) startRow = 1;
      int count = 0;
      for (int i = startRow; i < rows.length; i++) {
        final row = rows[i]; if (row.isEmpty) continue;
        final medicine = row[0].toString().trim();
        final quantity = row.length > 1 ? int.tryParse(row[1].toString().trim()) ?? 0 : 0;
        final reason = row.length > 2 ? row[2].toString().trim() : 'CSV Import';
        if (medicine.isNotEmpty && quantity > 0) { _indentItems.add({'medicine': medicine, 'requested': quantity, 'reason': reason}); count++; }
      }
      setState(() => _csvStatus = 'Imported $count items from ${file.name}');
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV Error: $e'))); }
  }

  Future<void> _submitIndent() async {
    if (_indentItems.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one item.'))); return; }
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Confirm Submission'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Submit ${_indentItems.length} item(s) to CMS:'),
        const SizedBox(height: 12),
        ..._indentItems.take(5).map((item) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• ${item['medicine']} — ${item['requested']} units', style: const TextStyle(fontWeight: FontWeight.w500)))),
        if (_indentItems.length > 5) Text('...and ${_indentItems.length - 5} more', style: const TextStyle(fontStyle: FontStyle.italic)),
        const SizedBox(height: 12),
        const Text('This action cannot be undone.', style: TextStyle(color: MediColors.error, fontSize: 12)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
      ],
    ));
    if (confirmed != true) return;
    setState(() => _isSubmitting = true);
    try {
      for (var item in _indentItems) {
        if (item['requested'] > 0) {
          final req = MedRequest(id: '', facilityId: widget.facilityId, medicineName: item['medicine'], type: RequestType.regularIndent, quantity: item['requested'], requestDate: DateTime.now(), status: RequestStatus.pending, notes: item['reason']);
          await ref.read(firebaseServiceProvider).addRequest(req);
        }
      }
      if (mounted) { setState(() { _indentItems.clear(); _csvStatus = null; }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted to CMS ✓'))); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
    finally { if (mounted) setState(() => _isSubmitting = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MediColors.bg,
      appBar: AppBar(title: const Text('Create Indent')),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: MediColors.info.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: MediColors.info.withValues(alpha: 0.15))),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: MediColors.info, size: 20),
              const SizedBox(width: 14),
              const Expanded(child: Text('Add items manually or upload a CSV (MedicineName, Quantity, Reason)', style: TextStyle(color: MediColors.textSecondary, fontSize: 13))),
            ]),
          ),
          if (_csvStatus != null) ...[
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: MediColors.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [const Icon(Icons.check_circle_rounded, color: MediColors.success, size: 18), const SizedBox(width: 10), Expanded(child: Text(_csvStatus!, style: const TextStyle(color: MediColors.success, fontSize: 13)))])),
          ],
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(color: MediColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: MediColors.border)),
              child: _indentItems.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.receipt_long_rounded, size: 52, color: MediColors.textMuted),
                      const SizedBox(height: 12),
                      Text('No items yet', style: TextStyle(color: MediColors.textMuted, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Upload CSV or add manually', style: TextStyle(color: MediColors.textMuted, fontSize: 12)),
                    ]))
                  : SingleChildScrollView(child: DataTable(
                      columns: const [DataColumn(label: Text('Medicine')), DataColumn(label: Text('Qty')), DataColumn(label: Text('Reason')), DataColumn(label: Text(''))],
                      rows: _indentItems.map((item) => DataRow(cells: [
                        DataCell(TextFormField(initialValue: item['medicine'], decoration: const InputDecoration(border: InputBorder.none, isDense: true), style: const TextStyle(color: MediColors.textPrimary), onChanged: (v) => item['medicine'] = v)),
                        DataCell(TextFormField(initialValue: item['requested'].toString(), keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, isDense: true), style: const TextStyle(color: MediColors.textPrimary), onChanged: (v) => item['requested'] = int.tryParse(v) ?? 0)),
                        DataCell(TextFormField(initialValue: item['reason'].toString(), decoration: const InputDecoration(border: InputBorder.none, isDense: true), style: const TextStyle(color: MediColors.textPrimary), onChanged: (v) => item['reason'] = v)),
                        DataCell(IconButton(icon: const Icon(Icons.delete_rounded, color: MediColors.error, size: 20), onPressed: () => setState(() => _indentItems.remove(item)))),
                      ])).toList())),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(spacing: 16, runSpacing: 12, alignment: WrapAlignment.spaceBetween, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              OutlinedButton.icon(icon: const Icon(Icons.add_rounded), label: const Text('Add Item'),
                onPressed: () => setState(() => _indentItems.add({'medicine': 'Paracetamol', 'requested': 100, 'reason': 'Manual'}))),
              const SizedBox(width: 12),
              OutlinedButton.icon(icon: const Icon(Icons.upload_file_rounded, color: MediColors.teal), label: const Text('Upload CSV', style: TextStyle(color: MediColors.teal)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: MediColors.teal)), onPressed: _pickAndParseCSV),
            ]),
            Container(
              decoration: BoxDecoration(gradient: MediColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
              child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18)),
                icon: const Icon(Icons.send_rounded), label: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Submit to CMS'),
                onPressed: _isSubmitting ? null : _submitIndent)),
          ]),
        ]),
      ),
    );
  }
}
