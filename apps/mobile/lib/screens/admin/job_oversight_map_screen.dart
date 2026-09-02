import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fiberjet/services/admin_data_service.dart';

class JobOversightMapScreen extends StatefulWidget {
  const JobOversightMapScreen({super.key});

  @override
  State<JobOversightMapScreen> createState() => _JobOversightMapScreenState();
}

class _JobOversightMapScreenState extends State<JobOversightMapScreen> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  Timer? _pollingTimer;

  bool _isLoading = true;
  String? _error;

  List<dynamic> _technicians = [];
  List<dynamic> _jobs = [];

  Set<Marker> _markers = {};

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(28.6139, 77.2090), // Default to New Delhi or your city
    zoom: 11.0,
  );

  @override
  void initState() {
    super.initState();
    _fetchLiveMapData();
    // Poll every 15 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) => _fetchLiveMapData());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLiveMapData() async {
    final res = await AdminDataService.getLiveMapData();
    if (!mounted) return;

    if (res.success) {
      setState(() {
        _isLoading = false;
        _technicians = res.data['technicians'] ?? [];
        _jobs = res.data['active_jobs'] ?? [];
        _updateMarkers();
      });
    } else {
      setState(() {
        _isLoading = false;
        _error = res.message;
      });
    }
  }

  void _updateMarkers() {
    final newMarkers = <Marker>{};

    for (var tech in _technicians) {
      if (tech['lat'] != null && tech['lng'] != null) {
        newMarkers.add(
          Marker(
            markerId: MarkerId('tech_${tech['id']}'),
            position: LatLng(
              double.tryParse(tech['lat'].toString()) ?? 0,
              double.tryParse(tech['lng'].toString()) ?? 0,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: InfoWindow(
              title: tech['name'],
              snippet: 'Technician - ${tech['phone']}',
            ),
          ),
        );
      }
    }

    for (var job in _jobs) {
      final cust = job['customer'] ?? {};
      if (cust['lat'] != null && cust['lng'] != null) {
        newMarkers.add(
          Marker(
            markerId: MarkerId('job_${job['id']}'),
            position: LatLng(
              double.tryParse(cust['lat'].toString()) ?? 0,
              double.tryParse(cust['lng'].toString()) ?? 0,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              job['status'] == 'started' ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
            ),
            infoWindow: InfoWindow(
              title: 'Job: ${job['type']}',
              snippet: 'Status: ${job['status']} | Cust: ${cust['name']}',
            ),
          ),
        );
      }
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Job Oversight', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : Stack(
              children: [
                GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: _initialPosition,
                  markers: _markers,
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                  },
                ),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
                
                // Overlay for summary
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn('Online Techs', _technicians.length.toString(), Colors.blue),
                          _buildStatColumn('Active Jobs', _jobs.length.toString(), Colors.redAccent),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
