import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import '../../services/firebase_service.dart';
import '../../models/request.dart';

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
      final rows = CsvToListConverter().convert(csvString);

      if (rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV file is empty.')),
          );
        }
        return;
      }

      // Detect if first row is a header
      int startRow = 0;
      final firstCell = rows[0][0].toString().toLowerCase().trim();
      if (firstCell.contains('medicine') || firstCell.contains('name') || firstCell.contains('drug')) {
        startRow = 1;
      }

      int importedCount = 0;
      for (int i = startRow; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;

        final medicine = row[0].toString().trim();
        final quantity = row.length > 1 ? int.tryParse(row[1].toString().trim()) ?? 0 : 0;
        final reason = row.length > 2 ? row[2].toString().trim() : 'CSV Import';

        if (medicine.isNotEmpty && quantity > 0) {
          _indentItems.add({
            'medicine': medicine,
            'requested': quantity,
            'reason': reason,
          });
          importedCount++;
        }
      }

      setState(() {
        _csvStatus = 'Imported $importedCount items from ${file.name}';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV Parse Error: $e')),
        );
      }
    }
  }

  Future<void> _submitIndent() async {
    if (_indentItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one item to indent.')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      for (var item in _indentItems) {
        if (item['requested'] > 0) {
          final req = MedRequest(
            id: '',
            facilityId: widget.facilityId,
            medicineName: item['medicine'],
            type: RequestType.regularIndent,
            quantity: item['requested'],
            requestDate: DateTime.now(),
            status: RequestStatus.pending,
            notes: item['reason'],
          );
          await ref.read(firebaseServiceProvider).addRequest(req);
        }
      }

      if (mounted) {
        setState(() {
          _indentItems.clear();
          _csvStatus = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indent requests successfully routed to CMS!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error Submitting: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Create Indent', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 16),
                  Expanded(child: Text('Add items manually or upload a CSV file (columns: MedicineName, Quantity, Reason).', style: TextStyle(color: Colors.blue))),
                ],
              ),
            ),
            if (_csvStatus != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_csvStatus!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Data table
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                child: _indentItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.upload_file, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('No items in current pending indent list.', style: TextStyle(color: Colors.grey[400], fontStyle: FontStyle.italic)),
                            const SizedBox(height: 8),
                            Text('Upload a CSV or add items manually.', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Medicine')),
                            DataColumn(label: Text('Requested Qty')),
                            DataColumn(label: Text('Reason')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: _indentItems.map((item) {
                            return DataRow(cells: [
                              DataCell(TextFormField(
                                initialValue: item['medicine'],
                                decoration: const InputDecoration(border: UnderlineInputBorder(), isDense: true),
                                onChanged: (val) => item['medicine'] = val,
                              )),
                              DataCell(TextFormField(
                                initialValue: item['requested'].toString(),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(border: UnderlineInputBorder(), isDense: true),
                                onChanged: (val) => item['requested'] = int.tryParse(val) ?? 0,
                              )),
                              DataCell(TextFormField(
                                initialValue: item['reason'].toString(),
                                decoration: const InputDecoration(border: UnderlineInputBorder(), isDense: true),
                                onChanged: (val) => item['reason'] = val,
                              )),
                              DataCell(IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _indentItems.remove(item)))),
                            ]);
                          }).toList(),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons row
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Manual Item'),
                      onPressed: () {
                        setState(() => _indentItems.add({'medicine': 'Paracetamol', 'requested': 100, 'reason': 'Manual Indent'}));
                      },
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.upload_file, color: Colors.teal),
                      label: const Text('Upload CSV', style: TextStyle(color: Colors.teal)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.teal)),
                      onPressed: _pickAndParseCSV,
                    ),
                  ],
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.send),
                  label: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit to CMS'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20)),
                  onPressed: _isSubmitting ? null : _submitIndent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
