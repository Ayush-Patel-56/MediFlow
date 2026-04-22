import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/facility.dart';
import '../../models/request.dart';
import '../../services/firebase_service.dart';
import '../../services/ai_service.dart';

class RouteOptimizationMap extends ConsumerStatefulWidget {
  const RouteOptimizationMap({super.key});

  @override
  ConsumerState<RouteOptimizationMap> createState() => _RouteOptimizationMapState();
}

class _RouteOptimizationMapState extends ConsumerState<RouteOptimizationMap> {
  List<Facility> _facilities = [];
  bool _isLoading = true;
  bool _showRoutes = false;
  String _aiSummary = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final facs = await ref.read(firebaseServiceProvider).getFacilities();
    if (mounted) {
      setState(() {
        _facilities = facs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final mapCenter = _facilities.isNotEmpty 
        ? LatLng(_facilities.first.latitude, _facilities.first.longitude) 
        : const LatLng(28.6139, 77.2090); // Default to Delhi

    // Stream organic requests from Phase 2
    final requestsStream = ref.watch(firebaseServiceProvider).streamRequests(null);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Route Optimization View', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<MedRequest>>(
        stream: requestsStream,
        builder: (context, snapshot) {
          final requests = snapshot.data ?? [];
          
          // Logic: Build organic distribution paths by finding matching medicine requests between Surplus and Shortage
          List<Map<String, dynamic>> routeMatches = [];
          if (_showRoutes && requests.isNotEmpty) {
            final surpluses = requests.where((r) => r.type == RequestType.surplus).toList();
            final shortages = requests.where((r) => r.type == RequestType.shortage || r.type == RequestType.regularIndent).toList();

            for (var shortage in shortages) {
              final match = surpluses.where((s) => s.medicineName == shortage.medicineName && s.facilityId != shortage.facilityId).firstOrNull;
              if (match != null) {
                final fromFac = _facilities.firstWhere((f) => f.id == match.facilityId, orElse: () => _facilities.first);
                final toFac = _facilities.firstWhere((f) => f.id == shortage.facilityId, orElse: () => _facilities.first);
                
                // Calculate distance manually mathematically 
                final Distance distanceCalc = const Distance();
                final meter = distanceCalc(
                  LatLng(fromFac.latitude, fromFac.longitude),
                  LatLng(toFac.latitude, toFac.longitude)
                );
                
                routeMatches.add({
                  'from': fromFac,
                  'to': toFac,
                  'medicine': shortage.medicineName,
                  'qty': shortage.quantity,
                  'distance': '${(meter / 1000).toStringAsFixed(1)} km',
                  'time': '${(meter / 1000 / 40).ceil()}h',
                });
              }
            }
          }

          return Row(
            children: [
              // Left Panel: Logistics Details
              Container(
                width: 400,
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Transfer Manifest', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('AI-optimized redistribution paths derived directly from live Indent Orders.', style: TextStyle(color: Colors.grey[600])),
                          const SizedBox(height: 16),
                          if (_aiSummary.isNotEmpty && _showRoutes)
                             Container(
                               padding: const EdgeInsets.all(12),
                               decoration: BoxDecoration(color: Colors.indigo.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                               child: Text(_aiSummary, style: TextStyle(color: Colors.indigo[900], fontStyle: FontStyle.italic)),
                             ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton.icon(
                              icon: const Icon(Icons.route),
                              label: Text(_showRoutes ? 'Hide Routes' : 'Generate Optimal Routes'),
                              onPressed: () async {
                                if (!_showRoutes) {
                                  // Call AI organically using realtime mapping
                                  final summary = await ref.read(aiServiceProvider).generateRedistributionPlan(requests, _facilities);
                                  setState(() {
                                    _aiSummary = summary;
                                    _showRoutes = true;
                                  });
                                } else {
                                  setState(() => _showRoutes = false);
                                }
                              },
                            ),
                          )
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: !_showRoutes 
                        ? Center(child: Text('Generate routes to see manifest', style: TextStyle(color: Colors.grey[500])))
                        : ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                              if (routeMatches.isEmpty) ...[
                                const Text('No matching Surplus/Shortage vectors found among unfulfilled active Indents.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                const SizedBox(height: 12),
                                const Text('Generate requests matching identical medicines on different facilities to populate routes.', style: TextStyle(color: Colors.grey)),
                              ] else ...[
                                ...routeMatches.map((match) => _buildTransferCard(
                                  from: match['from'].name,
                                  to: match['to'].name,
                                  medicine: match['medicine'],
                                  quantity: '${match['qty']} units',
                                  distance: match['distance'],
                                  time: match['time'],
                                )),
                              ]
                            ],
                          ),
                    ),
                  ],
                ),
              ),
              
              // Right Panel: Map
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: mapCenter,
                        initialZoom: 10.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.mediflow.app',
                        ),
                        if (_showRoutes && routeMatches.isNotEmpty)
                          PolylineLayer<Object>(
                            polylines: routeMatches.map((m) {
                              Facility fromF = m['from'];
                              Facility toF = m['to'];
                              return Polyline(
                                points: [
                                  LatLng(fromF.latitude, fromF.longitude),
                                  LatLng(toF.latitude, toF.longitude),
                                ],
                                color: Colors.indigo,
                                strokeWidth: 4.0,
                              );
                            }).toList(),
                          ),
                        MarkerLayer(
                          markers: _facilities.map((f) {
                            return Marker(
                              point: LatLng(f.latitude, f.longitude),
                              width: 80,
                              height: 80,
                              child: const Column(
                                children: [
                                  Icon(Icons.local_hospital, color: Colors.red, size: 40),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    // Map overlay legend
                    Positioned(
                      bottom: 24,
                      right: 24,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Legend', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Row(children: [Container(width: 16, height: 16, color: Colors.indigo), const SizedBox(width: 8), const Text('Active Transfer Vector')]),
                            const SizedBox(height: 8),
                            const Row(children: [Icon(Icons.local_hospital, color: Colors.red, size: 16), SizedBox(width: 8), Text('Registered Facility')]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildTransferCard({required String from, required String to, required String medicine, required String quantity, required String distance, required String time}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.outbound, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(from, style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Icon(Icons.arrow_downward, color: Colors.grey, size: 16),
          ),
          Row(
            children: [
              const Icon(Icons.input, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(to, style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(medicine, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(quantity, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(children: [const Icon(Icons.route, size: 14, color: Colors.indigo), const SizedBox(width: 4), Text(distance, style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold))]),
                  Row(children: [const Icon(Icons.schedule, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(time, style: const TextStyle(color: Colors.grey))]),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
