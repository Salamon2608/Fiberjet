import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fiberjet/services/tech_data_service.dart';

class TechModemScreen extends StatefulWidget {
  final String customerId;
  final String customerName;

  const TechModemScreen({super.key, required this.customerId, required this.customerName});

  @override
  State<TechModemScreen> createState() => _TechModemScreenState();
}

class _TechModemScreenState extends State<TechModemScreen> {
  static const Color _navy = Color(0xFF1E3A8A);

  bool _isLoading = true;
  bool _isRebooting = false;
  int _rebootCooldown = 0;
  Timer? _refreshTimer;
  Timer? _cooldownTimer;
  Map<String, dynamic>? _modem;

  @override
  void initState() {
    super.initState();
    _fetchModem();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchModem(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchModem({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final result = await TechDataService.getModemInfo(widget.customerId);
    if (result.success) {
      setState(() {
        _modem = result.data as Map<String, dynamic>?;
        if (!silent) _isLoading = false;
      });
    } else {
      if (!silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _rebootModem() async {
    if (_rebootCooldown > 0 || _isRebooting) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reboot Router?'),
        content: const Text('This will temporarily disconnect the customer. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Reboot'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isRebooting = true);
    final result = await TechDataService.rebootModem(widget.customerId);
    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message), backgroundColor: Colors.green));
      setState(() {
        _isRebooting = false;
        _rebootCooldown = 300; // 5 minutes
      });
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        setState(() {
          _rebootCooldown--;
          if (_rebootCooldown <= 0) { _rebootCooldown = 0; t.cancel(); }
        });
      });
      _fetchModem();
    } else {
      setState(() => _isRebooting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: Text('${widget.customerName} — Router', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : _modem == null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.router, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('No modem linked', style: GoogleFonts.inter(fontSize: 16, color: Colors.grey)),
                ]))
              : RefreshIndicator(
                  onRefresh: _fetchModem,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      _buildSignalGauge(),
                      const SizedBox(height: 16),
                      _buildDeviceInfo(),
                      const SizedBox(height: 16),
                      _buildRebootButton(),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
    );
  }

  Widget _buildSignalGauge() {
    final status = _modem!['status'];
    final signal = _modem!['signal_strength'] as int? ?? -100;
    final quality = _modem!['signal_quality']?.toString() ?? 'critical';
    final isOnline = _modem!['is_online'] == true;

    Color gaugeColor;
    IconData gaugeIcon;
    String statusText;
    double progress;

    if (_isRebooting || !isOnline) {
      gaugeColor = Colors.red;
      gaugeIcon = Icons.power_off;
      statusText = _isRebooting ? 'Rebooting...' : 'Offline';
      progress = 0.05;
    } else {
      switch (quality) {
        case 'excellent': gaugeColor = Colors.green; gaugeIcon = Icons.signal_wifi_4_bar; statusText = 'Excellent'; progress = 0.95; break;
        case 'very_good': gaugeColor = Colors.blue; gaugeIcon = Icons.network_wifi; statusText = 'Very Good'; progress = 0.75; break;
        case 'good': gaugeColor = Colors.orange; gaugeIcon = Icons.signal_wifi_4_bar; statusText = 'Good'; progress = 0.55; break;
        case 'weak': gaugeColor = Colors.deepOrange; gaugeIcon = Icons.signal_wifi_bad; statusText = 'Weak'; progress = 0.3; break;
        default: gaugeColor = Colors.red; gaugeIcon = Icons.signal_wifi_off; statusText = 'Critical'; progress = 0.1;
      }
    }

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: gaugeColor.withValues(alpha: 0.1), blurRadius: 20)],
      ),
      child: Column(children: [
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [gaugeColor.withValues(alpha: 0.15), Colors.transparent]),
          ),
          child: Center(child: Icon(gaugeIcon, size: 48, color: gaugeColor)),
        ),
        const SizedBox(height: 16),
        Text(statusText, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: gaugeColor)),
        Text('$signal dBm', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(gaugeColor)),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Critical', style: GoogleFonts.inter(fontSize: 9, color: Colors.grey)),
          Text('Excellent', style: GoogleFonts.inter(fontSize: 9, color: Colors.grey)),
        ]),
      ]),
    );
  }

  Widget _buildDeviceInfo() {
    final mac = _modem!['mac_address']?.toString() ?? 'N/A';
    final ip = _modem!['ip_address']?.toString() ?? 'N/A';
    final type = _modem!['device_type']?.toString() ?? 'N/A';
    final lastSeen = _modem!['last_synced']?.toString();
    String lastText = 'N/A';
    if (lastSeen != null) {
      final dt = DateTime.tryParse(lastSeen);
      if (dt != null) lastText = '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Device Details', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _infoRow(Icons.router, 'Type', type),
        _infoRow(Icons.language, 'IP Address', ip),
        _infoRow(Icons.memory, 'MAC Address', mac),
        _infoRow(Icons.access_time, 'Last Synced', lastText),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 16, color: _navy),
        const SizedBox(width: 10),
        Text('$label:', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.end)),
      ]),
    );
  }

  Widget _buildRebootButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_isRebooting || _rebootCooldown > 0) ? null : _rebootModem,
        icon: _isRebooting
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.restart_alt, size: 20),
        label: Text(
          _isRebooting ? 'Rebooting...'
              : _rebootCooldown > 0 ? 'Cooldown (${(_rebootCooldown ~/ 60)}:${(_rebootCooldown % 60).toString().padLeft(2, '0')})'
              : 'Reboot Router',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red, foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
