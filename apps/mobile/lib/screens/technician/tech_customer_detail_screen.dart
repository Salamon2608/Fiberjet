import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fiberjet/services/tech_data_service.dart';
import 'tech_modem_screen.dart';

class TechCustomerDetailScreen extends StatefulWidget {
  final String customerId;
  final String customerName;

  const TechCustomerDetailScreen({super.key, required this.customerId, required this.customerName});

  @override
  State<TechCustomerDetailScreen> createState() => _TechCustomerDetailScreenState();
}

class _TechCustomerDetailScreenState extends State<TechCustomerDetailScreen> {
  static const Color _navy = Color(0xFF1E3A8A);
  static const Color _gold = Color(0xFFFBBF24);

  bool _isLoading = true;
  Map<String, dynamic> _profile = {};
  List<dynamic> _devices = [];
  List<dynamic> _tickets = [];
  List<dynamic> _jobs = [];

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() => _isLoading = true);
    final result = await TechDataService.getCustomerDetail(widget.customerId);
    if (result.success && result.data != null) {
      final data = result.data as Map<String, dynamic>;
      setState(() {
        _profile = (data['profile'] as Map<String, dynamic>?) ?? {};
        _devices = (data['network_devices'] as List?) ?? [];
        _tickets = (data['recent_tickets'] as List?) ?? [];
        _jobs = (data['job_history'] as List?) ?? [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _profile['name']?.toString() ?? '');
    final phoneController = TextEditingController(text: _profile['phone']?.toString() ?? '');
    final emailController = TextEditingController(text: _profile['email']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Profile Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _navy)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Phone is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Email is required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final res = await TechDataService.updateCustomerDetail(widget.customerId, {
                  'name': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'email': emailController.text.trim(),
                });
                if (ctx.mounted) {
                  if (res.success) {
                    Navigator.pop(ctx, true);
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(res.message), backgroundColor: Colors.red));
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated == true) {
      _fetchDetail();
    }
  }

  void _showEditModemDialog() async {
    final macVal = _profile['modem_mac']?.toString();
    final ipVal = _profile['modem_ip']?.toString();
    final typeVal = _profile['modem_type']?.toString();

    final macController = TextEditingController(text: (macVal == null || macVal == 'N/A') ? '' : macVal);
    final ipController = TextEditingController(text: (ipVal == null || ipVal == 'N/A') ? '192.168.1.1' : ipVal);
    final typeController = TextEditingController(text: (typeVal == null || typeVal == 'N/A') ? 'ONT Router' : typeVal);
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Modem / Router Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _navy)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: macController,
                decoration: const InputDecoration(labelText: 'MAC Address', hintText: 'AA:BB:CC:DD:EE:FF', border: OutlineInputBorder()),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'MAC Address is required';
                  }
                  final clean = val.trim();
                  final reg = RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$|^[0-9A-Fa-f]{12}$');
                  if (!reg.hasMatch(clean)) {
                    return 'Invalid MAC format';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: ipController,
                decoration: const InputDecoration(labelText: 'IP Address', hintText: '192.168.1.1', border: OutlineInputBorder()),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'IP Address is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: typeController,
                decoration: const InputDecoration(labelText: 'Device Type', hintText: 'ONT Router', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Device Type is required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final res = await TechDataService.updateCustomerDetail(widget.customerId, {
                  'modem_mac': macController.text.trim(),
                  'modem_ip': ipController.text.trim(),
                  'modem_type': typeController.text.trim(),
                });
                if (ctx.mounted) {
                  if (res.success) {
                    Navigator.pop(ctx, true);
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(res.message), backgroundColor: Colors.red));
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated == true) {
      _fetchDetail();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text(widget.customerName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.router),
            tooltip: 'Modem Monitor',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => TechModemScreen(customerId: widget.customerId, customerName: widget.customerName),
            )),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : RefreshIndicator(
              onRefresh: _fetchDetail,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _buildProfileCard(),
                  const SizedBox(height: 14),
                  _buildPlanCard(),
                  const SizedBox(height: 14),
                  _buildModemCard(),
                  const SizedBox(height: 14),
                  _buildDevicesSection(),
                  const SizedBox(height: 14),
                  _buildTicketsSection(),
                  const SizedBox(height: 14),
                  _buildJobsSection(),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
    );
  }

  Widget _buildProfileCard() {
    final name = _profile['name']?.toString() ?? 'N/A';
    final phone = _profile['phone']?.toString() ?? '';
    final email = _profile['email']?.toString() ?? '';
    final status = _profile['account_status']?.toString() ?? 'active';
    final isOnline = _profile['connection_status']?.toString() == 'online';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Stack(children: [
            CircleAvatar(radius: 28, backgroundColor: _navy.withValues(alpha: 0.1),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'C',
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: _navy))),
            Positioned(bottom: 0, right: 0, child: Container(width: 14, height: 14,
              decoration: BoxDecoration(color: isOnline ? Colors.green : Colors.red, shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2)))),
          ]),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                Expanded(child: Text(name, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700))),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: _navy),
                  visualDensity: VisualDensity.compact,
                  onPressed: _showEditProfileDialog,
                ),
              ],
            ),
            if (phone.isNotEmpty) Text(phone, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey)),
            if (email.isNotEmpty) Text(email, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'active' ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
            child: Text(status.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
              color: status == 'active' ? Colors.green : Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard() {
    final planName = _profile['plan_name']?.toString();
    if (planName == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(Icons.info_outline, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Text('No active plan', style: GoogleFonts.inter(color: Colors.orange, fontWeight: FontWeight.w500)),
        ]),
      );
    }

    final speed = _profile['speed_mbps'];
    final price = _profile['plan_price'];
    final expiry = _profile['expiry_date']?.toString().split('T')[0] ?? 'N/A';
    final dataUsed = _profile['data_used_gb'];
    final dataLimit = _profile['data_limit_gb'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_navy, _navy.withValues(alpha: 0.8)]),
        borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Active Plan', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
          Text('₹$price/mo', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _gold)),
        ]),
        const SizedBox(height: 6),
        Text('$planName • ${speed}Mbps', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 10),
        Row(children: [
          _planDetail(Icons.calendar_today, 'Expires', expiry),
          const SizedBox(width: 20),
          if (dataLimit != null) _planDetail(Icons.data_usage, 'Usage', '${dataUsed ?? 0}/${dataLimit}GB'),
        ]),
      ]),
    );
  }

  Widget _planDetail(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 12, color: Colors.white54),
      const SizedBox(width: 4),
      Text('$label: $value', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
    ]);
  }

  Widget _buildModemCard() {
    final signal = _profile['signal_strength'] as int?;
    final modemIp = _profile['modem_ip']?.toString() ?? 'N/A';
    final modemType = _profile['modem_type']?.toString() ?? 'N/A';
    final modemMac = _profile['modem_mac']?.toString() ?? 'N/A';
    final isOnline = _profile['connection_status']?.toString() == 'online';

    Color signalColor = Colors.grey;
    String signalLabel = 'N/A';
    if (signal != null) {
      if (signal > -30) { signalColor = Colors.green; signalLabel = 'Excellent'; }
      else if (signal > -50) { signalColor = Colors.blue; signalLabel = 'Very Good'; }
      else if (signal > -70) { signalColor = Colors.orange; signalLabel = 'Good'; }
      else { signalColor = Colors.red; signalLabel = 'Weak'; }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Router / Modem', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: _navy),
                visualDensity: VisualDensity.compact,
                onPressed: _showEditModemDialog,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.grey),
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => TechModemScreen(customerId: widget.customerId, customerName: widget.customerName),
                )),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: signalColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.router, color: signalColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: isOnline ? Colors.green : Colors.red, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(isOnline ? 'Online' : 'Offline', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isOnline ? Colors.green : Colors.red)),
              if (signal != null) ...[
                const SizedBox(width: 8),
                Text('$signalLabel (${signal}dBm)', style: GoogleFonts.inter(fontSize: 11, color: signalColor)),
              ],
            ]),
            const SizedBox(height: 4),
            Text('IP: $modemIp • $modemType', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
            Text('MAC: $modemMac', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
          ])),
        ]),
      ]),
    );
  }

  Widget _buildDevicesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Network Devices (${_devices.length})', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
        if (_devices.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text('No devices found', style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)))
        else
          ...(_devices.take(5).map((d) {
            final dev = d as Map<String, dynamic>;
            final devName = dev['device_name']?.toString() ?? 'Unknown Device';
            final mac = dev['mac_address']?.toString() ?? '';
            final isTrusted = dev['is_trusted'] == true;
            final isBlocked = dev['is_blocked'] == true;
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                Icon(Icons.devices, size: 18, color: isBlocked ? Colors.red : (isTrusted ? Colors.green : Colors.grey)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(devName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(mac, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isBlocked ? Colors.red.withValues(alpha: 0.1) : (isTrusted ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(4)),
                  child: Text(isBlocked ? 'Blocked' : (isTrusted ? 'Trusted' : 'Unknown'),
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600,
                          color: isBlocked ? Colors.red : (isTrusted ? Colors.green : Colors.grey))),
                ),
              ]),
            );
          })),
      ]),
    );
  }

  Widget _buildTicketsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Recent Tickets (${_tickets.length})', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
        if (_tickets.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text('No tickets', style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)))
        else
          ...(_tickets.map((t) {
            final ticket = t as Map<String, dynamic>;
            final title = ticket['title']?.toString() ?? 'Ticket';
            final status = ticket['status']?.toString() ?? 'open';
            final cat = ticket['category']?.toString() ?? '';
            Color sc = status == 'resolved' ? Colors.green : (status == 'open' ? Colors.orange : Colors.blue);
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                Icon(Icons.confirmation_number, size: 16, color: sc),
                const SizedBox(width: 8),
                Expanded(child: Text('$title • $cat', style: GoogleFonts.inter(fontSize: 12), overflow: TextOverflow.ellipsis)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text(status, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: sc)),
                ),
              ]),
            );
          })),
      ]),
    );
  }

  Widget _buildJobsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Job History (${_jobs.length})', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
        if (_jobs.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text('No jobs', style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)))
        else
          ...(_jobs.map((j) {
            final job = j as Map<String, dynamic>;
            final type = job['type']?.toString() ?? 'Job';
            final status = job['status']?.toString() ?? '';
            final addr = job['address']?.toString() ?? '';
            Color sc = status == 'completed' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.blue);
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                Icon(Icons.work, size: 16, color: sc),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(type, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  if (addr.isNotEmpty) Text(addr, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey), overflow: TextOverflow.ellipsis),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text(status, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: sc)),
                ),
              ]),
            );
          })),
      ]),
    );
  }
}
