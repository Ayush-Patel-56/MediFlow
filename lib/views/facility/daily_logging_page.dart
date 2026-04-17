import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/firebase_service.dart';

class DailyLoggingPage extends ConsumerStatefulWidget {
  final String facilityId;
  const DailyLoggingPage({super.key, required this.facilityId});

  @override
  ConsumerState<DailyLoggingPage> createState() => _DailyLoggingPageState();
}

class _DailyLoggingPageState extends ConsumerState<DailyLoggingPage> {
  DateTime _selectedDate = DateTime.now();
  final _formKey = GlobalKey<FormState>();
  String _medName = 'Paracetamol';
  int _quantity = 0;
  int _patients = 0;
  bool _isSubmitting = false;

  Future<void> _submitLog() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isSubmitting = true);
    
    try {
      await ref.read(firebaseServiceProvider).logUsage(
        facilityId: widget.facilityId,
        date: _selectedDate,
        medicineName: _medName,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Daily Logging', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          width: 500,
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
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
                  
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Medicine', border: OutlineInputBorder()),
                    value: _medName,
                    items: ['Paracetamol', 'Cough Syrup', 'ORS', 'Antibiotic', 'Vitamin Tablets']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setState(() => _medName = v!),
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
                      onPressed: _isSubmitting ? null : _submitLog,
                      child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Save Log'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
