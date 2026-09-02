import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fiberjet/services/customer_data_service.dart';

class ModemInfoScreen extends StatefulWidget {
  const ModemInfoScreen({super.key});

  @override
  State<ModemInfoScreen> createState() => _ModemInfoScreenState();
}

class _ModemInfoScreenState extends State<ModemInfoScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _modem;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchModemInfo();
    // Poll the backend every 10 seconds for real-time updates
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchModemInfo(isBackground: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchModemInfo({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() { _isLoading = true; });
    }
    final result = await CustomerDataService.getModemInfo();
    if (result.success) {
      setState(() {
        _modem = result.data as Map<String, dynamic>?;
        _isLoading = false;
      });
    } else {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFDB612)))
          : RefreshIndicator(
              onRefresh: _fetchModemInfo,
              color: const Color(0xFFFDB612),
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      clipBehavior: Clip.none, // Prevents cards from being cut off when overlapping
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        children: [
                          Transform.translate(
                            offset: const Offset(0, -40), // Balanced overlap
                            child: Column(
                              children: [
                                if (_modem == null) _buildNoModemState(isDarkMode)
                                else ...[
                                  _buildQuickStats(),
                                  const SizedBox(height: 24),
                                  _buildTechnicalSpecs(context, isDarkMode),
                                  const SizedBox(height: 24),
                                  _buildSignalStrength(isDarkMode),
                                  const SizedBox(height: 24),
                                  _buildActionButtons(isDarkMode),
                                ],
                                const SizedBox(height: 24),
                                _buildSupportCard(),
                                const SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildNoModemState(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Icon(Icons.router_outlined, size: 80, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('No Modem Linked', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'No modem/ONT device is linked to your account yet. Contact support if you believe this is an error.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final deviceType = _modem?['device_type'] ?? 'Unknown';
    final isOnline = _modem != null;

    return Container(
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 80),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: const Color(0xFFFDB612), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.bolt, color: Color(0xFF0F172A), size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Text('Fiber Jet', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFDB612).withValues(alpha: 0.3), width: 2),
                  boxShadow: [BoxShadow(color: const Color(0xFFFDB612).withValues(alpha: 0.2), blurRadius: 20)],
                ),
                child: const Icon(Icons.router, color: Color(0xFFFDB612), size: 64),
              ),
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0F172A), width: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            deviceType,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(
                color: isOnline ? const Color(0xFFFDB612) : Colors.red,
                shape: BoxShape.circle,
              )),
              const SizedBox(width: 8),
              Text(
                isOnline ? 'SYSTEM ONLINE' : 'OFFLINE',
                style: TextStyle(
                  color: isOnline ? const Color(0xFFFDB612) : Colors.red,
                  fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final lastSynced = _modem?['last_synced']?.toString();
    String uptimeText = 'Unknown';
    if (lastSynced != null) {
      final syncTime = DateTime.tryParse(lastSynced);
      if (syncTime != null) {
        final diff = DateTime.now().difference(syncTime);
        if (diff.inDays > 0) {
          uptimeText = '${diff.inDays}d ${diff.inHours % 24}h';
        } else {
          uptimeText = '${diff.inHours}h ${diff.inMinutes % 60}m';
        }
      }
    }

    return Row(
      children: [
        Expanded(child: _buildStatItem(Icons.speed, 'Connection', 'Fiber (FTTH)')),
        const SizedBox(width: 16),
        Expanded(child: _buildStatItem(Icons.timer_outlined, 'Last Synced', uptimeText)),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFFDB612), size: 24),
          const SizedBox(height: 8),
          Text(label.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTechnicalSpecs(BuildContext context, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Technical Specifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Icon(Icons.info_outline, color: Colors.grey, size: 20),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildDetailRow('MAC Address', _modem?['mac_address'] ?? 'N/A', Icons.fingerprint, showCopy: true),
          _buildDetailRow('IPv4 Address', _modem?['ip_address'] ?? 'N/A', Icons.language, badge: 'Dynamic'),
          _buildDetailRow('Device Type', _modem?['device_type'] ?? 'N/A', Icons.router),
          _buildDetailRow('Device ID', _modem?['id']?.toString() ?? 'N/A', Icons.tag),
          _buildDetailRow('Last Heartbeat', _modem?['last_synced']?.toString().split('.').first ?? 'N/A', Icons.sync),
        ],
      ),
    );
  }

  Widget _buildSignalStrength(bool isDarkMode) {
    final signalRaw = _modem?['signal_strength'];
    final signal = signalRaw is num ? signalRaw.toInt() : int.tryParse(signalRaw?.toString() ?? '') ?? 0;
    int percentage = 0;
    Color color = Colors.red;
    String label = 'Offline';

    if (signal < 0) {
      // dBm scale: Best is -10 (100%), Worst is -40 (0%). Anything below -40 is 0%.
      percentage = ((signal + 40) / 30 * 100).clamp(0, 100).toInt();
      
      if (signal >= -20) {
        label = 'Excellent';
        color = Colors.green;
      } else if (signal >= -26) {
        label = 'Good';
        color = Colors.orange;
      } else if (signal >= -30) {
        label = 'Weak';
        color = Colors.redAccent;
      } else {
        label = 'Critical';
        color = Colors.red;
      }
    } else {
      // Direct percentage fallback
      percentage = signal.clamp(0, 100);
      if (percentage > 70) {
        label = 'Excellent';
        color = Colors.green;
      } else if (percentage > 40) {
        label = 'Good';
        color = Colors.orange;
      } else {
        label = 'Weak';
        color = Colors.red;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Signal Strength', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('$signal', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 4),
              Text(signal < 0 ? 'dBm' : '%', style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 10,
              backgroundColor: Colors.grey.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {bool showCopy = false, String? badge}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: const Color(0xFF1E293B), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (showCopy)
            IconButton(
              icon: const Icon(Icons.content_copy, color: Color(0xFFFDB612), size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('$label copied'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ));
              },
            ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
              child: Text(badge, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDarkMode) {
    bool isRebooting = false;
    
    return Column(
      children: [
        StatefulBuilder(
          builder: (context, setBtnState) {
            return ElevatedButton(
              onPressed: isRebooting ? null : () async {
                setBtnState(() => isRebooting = true);
                
                // Show UX loading
                showDialog(
                  context: context, 
                  barrierDismissible: false,
                  builder: (_) => const AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFFDB612)),
                        SizedBox(height: 16),
                        Text('Sending reboot signal...', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('This may take a few seconds.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  )
                );

                final res = await CustomerDataService.rebootModem();
                
                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  
                  if (res.success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Device is restarting. Connection will drop temporarily.'), backgroundColor: Colors.green),
                    );
                    _fetchModemInfo(); // Immediately fetch to show it offline (-100 dBm)
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res.message ?? 'Failed to send reboot command')),
                    );
                  }
                  
                  // Keep button disabled for 30 seconds while it "reboots"
                  Future.delayed(const Duration(seconds: 30), () {
                    if (mounted) setBtnState(() => isRebooting = false);
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isRebooting ? Colors.grey : const Color(0xFFFDB612),
                foregroundColor: const Color(0xFF0F172A),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: isRebooting ? 0 : 8,
                shadowColor: const Color(0xFFFDB612).withValues(alpha: 0.3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isRebooting ? Icons.hourglass_top : Icons.restart_alt),
                  const SizedBox(width: 8),
                  Text(isRebooting ? 'Rebooting...' : 'Reboot Device', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            );
          }
        ),
      ],
    );
  }

  Widget _buildSupportCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDB612).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFDB612).withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: Color(0xFFFDB612),
            child: Icon(Icons.support_agent, color: Color(0xFF0F172A), size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Need help with your hardware?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Our technical team is available 24/7 for Fiber Jet users.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
