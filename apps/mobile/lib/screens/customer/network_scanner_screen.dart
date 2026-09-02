import 'package:flutter/material.dart';
import 'package:fiberjet/services/customer_data_service.dart';

class NetworkScannerScreen extends StatefulWidget {
  const NetworkScannerScreen({super.key});

  @override
  State<NetworkScannerScreen> createState() => _NetworkScannerScreenState();
}

class _NetworkScannerScreenState extends State<NetworkScannerScreen> {
  bool _isLoading = false;
  bool _isScanning = false;
  String? _error;
  List<Map<String, dynamic>> _devices = [];
  double _scanProgress = 0.0;
  DateTime? _lastScanTime;

  // 30-minute auto-scan
  static const _autoScanInterval = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    _loadCachedDevices();
  }

  /// Load cached devices from the backend (GET - fast, no scan)
  Future<void> _loadCachedDevices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await CustomerDataService.getNetworkDevices();
      if (!mounted) return;

      if (result.success) {
        final data = result.data;
        final List deviceList = data is List ? data : [];
        setState(() {
          _devices = deviceList.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result.message ?? 'Failed to fetch devices';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Trigger a real-time network scan on the backend (POST - scans ARP table)
  Future<void> _triggerRealScan() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _error = null;
      _scanProgress = 0.0;
    });

    // Animate the progress bar during the scan
    _animateProgress();

    try {
      final result = await CustomerDataService.triggerNetworkScan();
      if (!mounted) return;

      if (result.success) {
        final data = result.data;
        final List deviceList = data is List ? data : [];
        setState(() {
          _devices = deviceList.cast<Map<String, dynamic>>();
          _scanProgress = 1.0;
          _isScanning = false;
          _lastScanTime = DateTime.now();
        });
      } else {
        setState(() {
          _error = result.message ?? 'Scan failed';
          _isScanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isScanning = false;
        });
      }
    }

    // Schedule next auto-scan
    _scheduleAutoScan();
  }

  void _scheduleAutoScan() {
    Future.delayed(_autoScanInterval, () {
      if (mounted) _triggerRealScan();
    });
  }

  Future<void> _animateProgress() async {
    for (int i = 0; i <= 100; i += 2) {
      if (!mounted || !_isScanning) break;
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted && _isScanning) {
        setState(() {
          _scanProgress = i / 100;
        });
      }
    }
  }

  String _getLastScanText() {
    if (_lastScanTime == null) return 'Not scanned yet';
    final diff = DateTime.now().difference(_lastScanTime!);
    if (diff.inSeconds < 60) return 'Last scan: Just now';
    if (diff.inMinutes < 60) return 'Last scan: ${diff.inMinutes}m ago';
    return 'Last scan: ${diff.inHours}h ago';
  }

  Future<void> _updateAccess(String id, String accessLevel) async {
    try {
      final result =
          await CustomerDataService.updateDeviceAccess(id, accessLevel);
      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Device ${accessLevel == 'blocked' ? 'blocked' : 'trusted'} successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCachedDevices(); // Refresh
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Failed to update access'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _error != null && _devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text('Error: $_error',
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadCachedDevices,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFDB612),
                            foregroundColor: const Color(0xFF0F172A),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadCachedDevices,
                    color: const Color(0xFFFDB612),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildScanSection(),
                          const SizedBox(height: 32),
                          _buildDeviceListHeader(),
                          const SizedBox(height: 16),
                          if (_isLoading && _devices.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(
                                  color: Color(0xFFFDB612)),
                            )
                          else ...[
                            ..._devices.map((d) => _buildDeviceItem(d)),
                            if (_devices.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('No devices found.',
                                    style: TextStyle(color: Colors.grey)),
                              ),
                          ],
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDB612),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFFDB612).withValues(alpha: 0.3),
                        blurRadius: 10),
                  ],
                ),
                child: const Icon(Icons.rocket_launch,
                    color: Color(0xFF0F172A), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Fiber Jet',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Network Security',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const Icon(Icons.notifications_outlined, color: Colors.white70),
        ],
      ),
    );
  }

  Widget _buildScanSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: _triggerRealScan,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isScanning)
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: _scanProgress,
                    color: const Color(0xFFFDB612),
                    strokeWidth: 4,
                  ),
                ),
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: _isScanning
                      ? const Color(0xFFFDB612).withValues(alpha: 0.5)
                      : const Color(0xFFFDB612),
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (!_isScanning)
                      BoxShadow(
                          color:
                              const Color(0xFFFDB612).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10)),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.radar,
                        color: const Color(0xFF0F172A),
                        size: _isScanning ? 30 : 40),
                    const SizedBox(height: 4),
                    Text(
                      _isScanning
                          ? '${(_scanProgress * 100).toInt()}%'
                          : 'SCAN NOW',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _devices.isEmpty && !_isLoading
                  ? Icons.shield_outlined
                  : Icons.shield,
              color: Colors.green,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              _devices.isEmpty && _isLoading
                  ? 'Scanning Network...'
                  : 'Network Secure',
              style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _isScanning ? 'Scanning your network...' : _getLastScanText(),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDeviceListHeader() {
    final count = _devices.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Connected Devices',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count Found',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceItem(Map<String, dynamic> device) {
    final deviceName = device['device_name'] ?? 'Unknown Device';
    final ipAddress = device['ip_address'] ?? '';
    final macAddress = device['mac_address'] ?? '';
    final deviceType = device['device_type'] ?? 'unknown';
    final status = device['status'] ?? 'offline';
    final accessLevel = device['access_level'] ?? 'unknown';
    final deviceId = device['id']?.toString() ?? '';

    // Pick icon & color based on device type from backend
    IconData icon;
    Color iconColor;
    switch (deviceType.toString().toLowerCase()) {
      case 'router':
      case 'gateway':
        icon = Icons.router;
        iconColor = Colors.orange;
        break;
      case 'smartphone':
      case 'phone':
      case 'mobile':
        icon = Icons.smartphone;
        iconColor = Colors.blue;
        break;
      case 'tv':
      case 'smart_tv':
        icon = Icons.tv;
        iconColor = Colors.purple;
        break;
      case 'laptop':
      case 'desktop':
      case 'pc':
      case 'computer':
        icon = Icons.laptop_mac;
        iconColor = Colors.teal;
        break;
      case 'printer':
        icon = Icons.print;
        iconColor = Colors.brown;
        break;
      case 'speaker':
      case 'smart_speaker':
        icon = Icons.speaker_group;
        iconColor = Colors.indigo;
        break;
      case 'tablet':
        icon = Icons.tablet_mac;
        iconColor = Colors.cyan;
        break;
      default:
        icon = Icons.devices_other;
        iconColor = Colors.grey;
        break;
    }

    final isOnline = status.toString().toLowerCase() == 'online';
    final isBlocked = accessLevel.toString().toLowerCase() == 'blocked';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isBlocked
                ? Colors.red.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            deviceName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isBlocked
                                ? Colors.red
                                : isOnline
                                    ? Colors.green
                                    : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('IP: $ipAddress',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            fontFamily: 'monospace')),
                    if (macAddress.isNotEmpty)
                      Text('MAC: $macAddress',
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 10,
                              fontFamily: 'monospace')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    isBlocked ? 'Blocked' : 'Trusted',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isBlocked ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 20, color: Colors.grey[200]),
              Expanded(
                child: TextButton(
                  onPressed: () => _updateAccess(
                      deviceId, isBlocked ? 'trusted' : 'blocked'),
                  child: Text(
                    isBlocked ? 'Trust Device' : 'Block Access',
                    style: TextStyle(
                      color: isBlocked ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
