import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import '../../services/firebase_service.dart';

class DailyLoggingPage extends ConsumerStatefulWidget {
  final String facilityId;
  const DailyLoggingPage({super.key, required this.facilityId});

  @override
  ConsumerState<DailyLoggingPage> createState() => _DailyLoggingPageState();
}

class _DailyLoggingPageState extends ConsumerState<DailyLoggingPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Manual form state
  DateTime _selectedDate = DateTime.now();
  final _formKey = GlobalKey<FormState>();
  String? _medName;
  int _quantity = 0;
  int _patients = 0;
  bool _isSubmitting = false;

  List<String> _availableMedicines = [];
  bool _isLoadingInventory = true;

  // CSV state
  List<Map<String, dynamic>> _csvItems = [];
  String? _csvStatus;
  bool _isSubmittingCsv = false;

  // QR state
  bool _isScanning = false;
  List<Map<String, dynamic>> _scannedItems = [];
  bool _isSubmittingQr = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchInventory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchInventory() async {
    try {
      final items = await ref.read(firebaseServiceProvider).getInventoryOnce(widget.facilityId);
      if (mounted) {
        setState(() {
          _availableMedicines = items.map((i) => i.medicineName).toList();
          if (_availableMedicines.isNotEmpty) _medName = _availableMedicines.first;
          _isLoadingInventory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingInventory = false);
    }
  }

  // --- Manual Submit ---
  Future<void> _submitLog() async {
    if (!_formKey.currentState!.validate() || _medName == null) return;
    _formKey.currentState!.save();
    setState(() => _isSubmitting = true);

    try {
      await ref.read(firebaseServiceProvider).logUsage(
        facilityId: widget.facilityId,
        date: _selectedDate,
        medicineName: _medName!,
        quantity: _quantity,
        patients: _patients,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Log saved successfully')));
        _formKey.currentState!.reset();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // --- CSV Upload ---
  Future<void> _pickCSV() async {
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
      if (rows.isEmpty) return;

      int startRow = 0;
      final firstCell = rows[0][0].toString().toLowerCase().trim();
      if (firstCell.contains('medicine') || firstCell.contains('name') || firstCell.contains('drug')) {
        startRow = 1;
      }

      final parsed = <Map<String, dynamic>>[];
      for (int i = startRow; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;
        final med = row[0].toString().trim();
        final qty = row.length > 1 ? int.tryParse(row[1].toString().trim()) ?? 0 : 0;
        final pat = row.length > 2 ? int.tryParse(row[2].toString().trim()) ?? 0 : 0;
        if (med.isNotEmpty && qty > 0) {
          parsed.add({'medicine': med, 'quantity': qty, 'patients': pat});
        }
      }

      setState(() {
        _csvItems = parsed;
        _csvStatus = 'Parsed ${parsed.length} entries from ${file.name}';
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV Error: $e')));
    }
  }

  Future<void> _submitCSVLogs() async {
    if (_csvItems.isEmpty) return;
    setState(() => _isSubmittingCsv = true);
    try {
      for (var item in _csvItems) {
        await ref.read(firebaseServiceProvider).logUsage(
          facilityId: widget.facilityId,
          date: _selectedDate,
          medicineName: item['medicine'],
          quantity: item['quantity'],
          patients: item['patients'],
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_csvItems.length} logs saved successfully!')));
        setState(() { _csvItems.clear(); _csvStatus = null; });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmittingCsv = false);
    }
  }

  // --- QR Scan Simulation ---
  Future<void> _simulateQRScan() async {
    setState(() => _isScanning = true);
    // Simulate camera scan delay
    await Future.delayed(const Duration(seconds: 2));

    // In production this would decode a QR code from camera.
    // For web demo, we simulate a decoded QR payload.
    if (_availableMedicines.isNotEmpty) {
      final med = _availableMedicines[DateTime.now().second % _availableMedicines.length];
      final qty = 10 + (DateTime.now().millisecond % 40);
      setState(() {
        _scannedItems.add({'medicine': med, 'quantity': qty, 'patients': (qty / 3).round()});
        _isScanning = false;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scanned: $med × $qty')));
    } else {
      setState(() => _isScanning = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No inventory to scan against.')));
    }
  }

  Future<void> _submitScannedLogs() async {
    if (_scannedItems.isEmpty) return;
    setState(() => _isSubmittingQr = true);
    try {
      for (var item in _scannedItems) {
        await ref.read(firebaseServiceProvider).logUsage(
          facilityId: widget.facilityId,
          date: _selectedDate,
          medicineName: item['medicine'],
          quantity: item['quantity'],
          patients: item['patients'],
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_scannedItems.length} scanned logs saved!')));
        setState(() => _scannedItems.clear());
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmittingQr = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Daily Logging', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.edit_note), text: 'Manual Entry'),
            Tab(icon: Icon(Icons.upload_file), text: 'CSV Upload'),
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan QR'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildManualTab(),
          _buildCsvTab(),
          _buildQrTab(),
        ],
      ),
    );
  }

  // ============ TAB 1: Manual Entry ============
  Widget _buildManualTab() {
    return Center(
      child: Container(
        width: 500,
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Log Medicine Usage', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('This data feeds directly into the AI forecasting model.', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 32),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (date != null) setState(() => _selectedDate = date);
                  },
                ),
                const SizedBox(height: 16),

                if (_isLoadingInventory)
                  const Center(child: CircularProgressIndicator())
                else if (_availableMedicines.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.orange.withValues(alpha: 0.1),
                    child: const Text('No active inventory found in this facility.', style: TextStyle(color: Colors.orange)),
                  )
                else
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Medicine', border: OutlineInputBorder()),
                    value: _medName,
                    items: _availableMedicines.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setState(() => _medName = v),
                    validator: (v) => v == null ? 'Please select a medicine' : null,
                  ),
                const SizedBox(height: 16),

                TextFormField(
                  decoration: const InputDecoration(labelText: 'Units Distributed', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (v) => (int.tryParse(v ?? '') == null) ? 'Enter valid number' : null,
                  onSaved: (v) => _quantity = int.parse(v!),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  decoration: const InputDecoration(labelText: 'Patients Served', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (v) => (int.tryParse(v ?? '') == null) ? 'Enter valid number' : null,
                  onSaved: (v) => _patients = int.parse(v!),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: (_isSubmitting || _availableMedicines.isEmpty) ? null : _submitLog,
                    child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Save Log'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============ TAB 2: CSV Upload ============
  Widget _buildCsvTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.shade200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.upload_file, color: Colors.teal[700], size: 28),
                    const SizedBox(width: 12),
                    Text('Bulk CSV Import', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.teal[900])),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Upload a CSV with columns: MedicineName, UnitsDistributed, PatientsServed', style: TextStyle(color: Colors.teal[700])),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.file_open),
                  label: const Text('Choose CSV File'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.teal, side: const BorderSide(color: Colors.teal)),
                  onPressed: _pickCSV,
                ),
              ],
            ),
          ),

          if (_csvStatus != null) ...[
            const SizedBox(height: 16),
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

          if (_csvItems.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Medicine')),
                    DataColumn(label: Text('Units')),
                    DataColumn(label: Text('Patients')),
                    DataColumn(label: Text('')),
                  ],
                  rows: _csvItems.map((item) => DataRow(cells: [
                    DataCell(Text(item['medicine'], style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(item['quantity'].toString())),
                    DataCell(Text(item['patients'].toString())),
                    DataCell(IconButton(
                      icon: const Icon(Icons.close, color: Colors.red, size: 18),
                      onPressed: () => setState(() => _csvItems.remove(item)),
                    )),
                  ])).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                icon: const Icon(Icons.save),
                label: _isSubmittingCsv
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Submit All ${_csvItems.length} Logs'),
                onPressed: _isSubmittingCsv ? null : _submitCSVLogs,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============ TAB 3: QR Scanner ============
  Widget _buildQrTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scanner area
          Container(
            width: double.infinity,
            height: 280,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: _isScanning
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 60, height: 60,
                          child: CircularProgressIndicator(color: Colors.greenAccent, strokeWidth: 3),
                        ),
                        const SizedBox(height: 16),
                        Text('Scanning QR Code...', style: TextStyle(color: Colors.green[300], fontSize: 16)),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner, size: 80, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        Text('Point camera at medicine batch QR code', style: TextStyle(color: Colors.grey[500])),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Simulate QR Scan'),
                          style: FilledButton.styleFrom(backgroundColor: Colors.green),
                          onPressed: _simulateQRScan,
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text('On mobile devices, this will activate the camera for real QR scanning.', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic)),

          if (_scannedItems.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Scanned Items', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Medicine')),
                    DataColumn(label: Text('Units')),
                    DataColumn(label: Text('Patients')),
                    DataColumn(label: Text('')),
                  ],
                  rows: _scannedItems.map((item) => DataRow(cells: [
                    DataCell(Text(item['medicine'], style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(item['quantity'].toString())),
                    DataCell(Text(item['patients'].toString())),
                    DataCell(IconButton(
                      icon: const Icon(Icons.close, color: Colors.red, size: 18),
                      onPressed: () => setState(() => _scannedItems.remove(item)),
                    )),
                  ])).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan Another'),
                    onPressed: _isScanning ? null : _simulateQRScan,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.save),
                    label: _isSubmittingQr
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Submit ${_scannedItems.length} Logs'),
                    onPressed: _isSubmittingQr ? null : _submitScannedLogs,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
