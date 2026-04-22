import 'package:flutter/material.dart';

class IndentCreationPage extends StatefulWidget {
  final String facilityId;
  const IndentCreationPage({super.key, required this.facilityId});

  @override
  State<IndentCreationPage> createState() => _IndentCreationPageState();
}

class _IndentCreationPageState extends State<IndentCreationPage> {
  final List<Map<String, dynamic>> _indentItems = [
    {'medicine': 'Paracetamol', 'ai_suggested': 1200, 'requested': 1200, 'reason': 'AI Forecast (Winter Spike)'},
    {'medicine': 'Cough Syrup', 'ai_suggested': 800, 'requested': 800, 'reason': 'AI Forecast'},
  ];
  bool _isSubmitted = false;

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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.blue),
                  SizedBox(width: 16),
                  Text('This indent is pre-filled based on Gemini AI forecasts for the next 30 days.', style: TextStyle(color: Colors.blue)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Medicine')),
                    DataColumn(label: Text('AI Suggested')),
                    DataColumn(label: Text('Requested Quantity')),
                    DataColumn(label: Text('Reason')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: _indentItems.map((item) {
                    return DataRow(cells: [
                      DataCell(
                        item['reason'] == 'Manual' && !_isSubmitted
                            ? TextFormField(
                                initialValue: item['medicine'],
                                decoration: const InputDecoration(border: UnderlineInputBorder(), isDense: true),
                                onChanged: (val) => item['medicine'] = val,
                              )
                            : Text(item['medicine'], style: const TextStyle(fontWeight: FontWeight.bold))
                      ),
                      DataCell(Text(item['ai_suggested'].toString(), style: TextStyle(color: Colors.grey[600]))),
                      DataCell(TextFormField(
                        initialValue: item['requested'].toString(),
                        keyboardType: TextInputType.number,
                        readOnly: _isSubmitted,
                        decoration: const InputDecoration(border: UnderlineInputBorder(), isDense: true),
                        onChanged: (val) => item['requested'] = int.tryParse(val) ?? 0,
                      )),
                      DataCell(Text(item['reason'])),
                      DataCell(
                        _isSubmitted 
                        ? const Icon(Icons.check, color: Colors.green) 
                        : IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _indentItems.remove(item)))
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Manual Item'),
                  onPressed: _isSubmitted ? null : () {
                    setState(() => _indentItems.add({'medicine': 'New Medicine', 'ai_suggested': 0, 'requested': 0, 'reason': 'Manual'}));
                  },
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.send),
                  label: Text(_isSubmitted ? 'Submitted' : 'Submit to CMS'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20)),
                  onPressed: _isSubmitted ? null : () {
                    setState(() => _isSubmitted = true);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indent submitted successfully!')));
                  },
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
