import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/facility.dart';
import '../../models/request.dart';
import '../../services/firebase_service.dart';
import '../../services/ai_service.dart';
import '../../main.dart';

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
      backgroundColor: MediColors.bg,
      appBar: AppBar(
        title: const Text('Route Optimization'),
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
                color: MediColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Transfer Manifest', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: MediColors.textPrimary)),
                          const SizedBox(height: 8),
                          const Text('AI-optimized redistribution paths from live Indent Orders.', style: TextStyle(color: MediColors.textSecondary, fontSize: 13)),
                          const SizedBox(height: 16),
                          if (_aiSummary.isNotEmpty && _showRoutes)
                             Container(
                               padding: const EdgeInsets.all(12),
                               decoration: BoxDecoration(color: MediColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                               child: Text(_aiSummary, style: const TextStyle(color: MediColors.primaryLight, fontStyle: FontStyle.italic, fontSize: 13)),
                             ),
                           const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(gradient: MediColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                                icon: const Icon(Icons.route_rounded),
                                label: Text(_showRoutes ? 'Hide Routes' : 'Generate Routes'),
                                onPressed: () async {
                                  if (!_showRoutes) {
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
                            ),
                          )
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: !_showRoutes 
                        ? const Center(child: Text('Generate routes to see manifest', style: TextStyle(color: MediColors.textMuted)))
                        : ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                              if (routeMatches.isEmpty) ...[
                                const Text('No matching Surplus/Shortage vectors found.', style: TextStyle(fontWeight: FontWeight.bold, color: MediColors.warning)),
                                const SizedBox(height: 12),
                                const Text('Create matching medicine requests across facilities.', style: TextStyle(color: MediColors.textMuted)),
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
                                color: MediColors.primary,
                                strokeWidth: 4.0,
                              );
                            }).toList(),
                          ),
                        MarkerLayer(
                          markers: _facilities.map((f) {
                            return Marker(
                              point: LatLng(f.latitude, f.longitude),
                              width: 120,
                              height: 80,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_hospital, color: Colors.red, size: 36),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
                                    ),
                                    child: Text(
                                      f.name.length > 16 ? '${f.name.substring(0, 14)}…' : f.name,
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
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
                        decoration: BoxDecoration(color: MediColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: MediColors.border)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Legend', style: TextStyle(fontWeight: FontWeight.bold, color: MediColors.textPrimary)),
                            const SizedBox(height: 8),
                            Row(children: [Container(width: 16, height: 16, color: MediColors.primary), const SizedBox(width: 8), const Text('Transfer Vector', style: TextStyle(color: MediColors.textSecondary, fontSize: 12))]),
                            const SizedBox(height: 8),
                            const Row(children: [Icon(Icons.local_hospital, color: Colors.red, size: 16), SizedBox(width: 8), Text('Facility', style: TextStyle(color: MediColors.textSecondary, fontSize: 12))]),
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
      decoration: BoxDecoration(color: MediColors.surfaceLight, borderRadius: BorderRadius.circular(14), border: Border.all(color: MediColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.outbound_rounded, color: MediColors.warning, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(from, style: const TextStyle(fontWeight: FontWeight.w600, color: MediColors.textPrimary))),
          ]),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Icon(Icons.arrow_downward_rounded, color: MediColors.textMuted, size: 16)),
          Row(children: [
            const Icon(Icons.input_rounded, color: MediColors.success, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(to, style: const TextStyle(fontWeight: FontWeight.w600, color: MediColors.textPrimary))),
          ]),
          const Divider(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(medicine, style: const TextStyle(fontWeight: FontWeight.w600, color: MediColors.textPrimary)),
              Text(quantity, style: const TextStyle(color: MediColors.textMuted, fontSize: 12)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(children: [const Icon(Icons.route_rounded, size: 14, color: MediColors.primary), const SizedBox(width: 4), Text(distance, style: const TextStyle(color: MediColors.primary, fontWeight: FontWeight.w600))]),
              Row(children: [const Icon(Icons.schedule_rounded, size: 14, color: MediColors.textMuted), const SizedBox(width: 4), Text(time, style: const TextStyle(color: MediColors.textMuted))]),
            ]),
          ]),
        ],
      ),
    );
  }
}
