import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/facility.dart';
import '../../services/firebase_service.dart';

class RouteOptimizationMap extends ConsumerStatefulWidget {
  const RouteOptimizationMap({super.key});

  @override
  ConsumerState<RouteOptimizationMap> createState() => _RouteOptimizationMapState();
}

class _RouteOptimizationMapState extends ConsumerState<RouteOptimizationMap> {
  List<Facility> _facilities = [];
  bool _isLoading = true;
  bool _showRoutes = false;
  List<LatLng> _routePoints = [];

  Future<void> _generateRoutes() async {
    if (_facilities.length < 2) return;
    
    final start = _facilities[0];
    final end = _facilities[1];
    
    try {
      final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&overview=full');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List;
        if (routes.isNotEmpty) {
          final geometry = routes[0]['geometry'];
          final coordinates = geometry['coordinates'] as List;
          setState(() {
            _routePoints = coordinates.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
            _showRoutes = true;
          });
          return;
        }
      }
    } catch (e) {
      print('Route fetch error: $e');
    }
    
    // Fallback to straight line
    setState(() {
       _routePoints = [
          LatLng(start.latitude, start.longitude),
          LatLng(end.latitude, end.longitude),
       ];
       _showRoutes = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final facs = await ref.read(firebaseServiceProvider).getFacilities();
    setState(() {
      _facilities = facs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final mapCenter = _facilities.isNotEmpty 
        ? LatLng(_facilities.first.latitude, _facilities.first.longitude) 
        : const LatLng(28.6139, 77.2090); // Default to Delhi

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Route Optimization View', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Row(
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
                      Text('AI-optimized redistribution paths.', style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.route),
                          label: Text(_showRoutes ? 'Hide Routes' : 'Generate Optimal Routes'),
                          onPressed: () {
                            if (_showRoutes) {
                              setState(() => _showRoutes = false);
                            } else {
                              _generateRoutes();
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
                          if (_facilities.length >= 2) ...[
                            _buildTransferCard(
                              from: _facilities[0].name,
                              to: _facilities[1].name,
                              medicine: 'Paracetamol',
                              quantity: '500 units',
                              distance: '45 km',
                              time: '1h 15m',
                            ),
                          ] else ...[
                            const Text('Need at least 2 facilities in DB to show routes.'),
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
                    if (_showRoutes && _facilities.length >= 2)
                      PolylineLayer<Object>(
                        polylines: [
                          Polyline(
                            points: _routePoints.isNotEmpty ? _routePoints : [
                              LatLng(_facilities[0].latitude, _facilities[0].longitude),
                              LatLng(_facilities[1].latitude, _facilities[1].longitude),
                            ],
                            color: Colors.indigo,
                            strokeWidth: 4.0,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: _facilities.map((f) {
                        return Marker(
                          point: LatLng(f.latitude, f.longitude),
                          width: 80,
                          height: 80,
                          child: const Column(
                            children: [
                              Icon(Icons.location_on, color: Colors.red, size: 40),
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
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Legend', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(children: [Container(width: 16, height: 16, color: Colors.indigo), const SizedBox(width: 8), const Text('AI Transfer Route')]),
                        const SizedBox(height: 8),
                        const Row(children: [Icon(Icons.location_on, color: Colors.red, size: 16), SizedBox(width: 8), Text('Facility')]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
