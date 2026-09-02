import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fiberjet/services/tech_data_service.dart';
import 'active_job_screen.dart';
import 'tech_notifications_screen.dart';

class TechDashboardScreen extends StatefulWidget {
  const TechDashboardScreen({super.key});
  @override
  State<TechDashboardScreen> createState() => _TechDashboardScreenState();
}

class _TechDashboardScreenState extends State<TechDashboardScreen> {
  static const Color _primary = Color(0xFFFBBF24);
  static const Color _secondary = Color(0xFF1E3A8A);
  static const Color _bgLight = Color(0xFFF3F4F6);

  bool _isLoading = true;
  List<dynamic> _todayJobs = [];
  Map<String, dynamic> _counts = {};
  Map<String, dynamic> _earnings = {};
  Map<String, dynamic> _deviceHealth = {};
  List<dynamic> _urgentTickets = [];
  Map<String, dynamic>? _activeJob;
  int _totalCustomers = 0;
  bool _isOnline = false;

  @override
  void initState() { super.initState(); _fetchDashboard(); }

  Future<void> _fetchDashboard() async {
    setState(() => _isLoading = true);
    final result = await TechDataService.getDashboard();
    if (result.success && result.data != null) {
      final data = result.data as Map<String, dynamic>;
      setState(() {
        _todayJobs = (data['today_jobs'] as List?) ?? [];
        _counts = (data['counts'] as Map<String, dynamic>?) ?? {};
        _earnings = (data['earnings'] as Map<String, dynamic>?) ?? {};
        _deviceHealth = (data['device_health'] as Map<String, dynamic>?) ?? {};
        _urgentTickets = (data['urgent_tickets'] as List?) ?? [];
        _activeJob = data['active_job'] as Map<String, dynamic>?;
        _totalCustomers = data['total_customers'] ?? 0;
        _isOnline = data['is_online'] ?? false;
        _isLoading = false;
      });
    } else { setState(() => _isLoading = false); }
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() => _isOnline = value);
    final res = await TechDataService.toggleStatus(value);
    if (!res.success) {
      setState(() => _isOnline = !value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message.isEmpty ? 'Failed to update status' : res.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: SafeArea(
        top: false,
        child: Column(children: [
          _buildHeader(),
          Expanded(child: RefreshIndicator(
            onRefresh: _fetchDashboard, color: _primary,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _secondary))
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(children: [
                      _buildKpiRow(),
                      _buildDeviceHealth(),
                      _buildRouteStats(),
                      if (_activeJob != null) _buildActiveJob(_activeJob!),
                      if (_urgentTickets.isNotEmpty) _buildUrgentTickets(),
                      _buildUpcomingJobs(),
                    ]),
                  ),
          )),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 18),
      decoration: BoxDecoration(color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: _secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.rocket_launch, color: _secondary, size: 20)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RichText(text: TextSpan(children: [
              TextSpan(text: 'FIBER', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _secondary)),
              TextSpan(text: 'JET', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _primary)),
            ])),
            Text('Technician Panel', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
          ]),
        ]),
        Row(children: [
          Text(_isOnline ? 'Online' : 'Offline', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _isOnline ? Colors.green : Colors.grey)),
          Switch(
            value: _isOnline,
            onChanged: _toggleOnline,
            activeColor: Colors.green,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TechNotificationsScreen())),
            child: Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade100),
              child: const Icon(Icons.notifications_rounded, color: Colors.grey, size: 22)),
          ),
        ]),
      ]),
    );
  }

  Widget _buildKpiRow() {
    final completed = _counts['completed'] ?? 0;
    final total = _counts['total'] ?? 0;
    final daily = _earnings['daily'] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
        Expanded(child: _kpiCard('Jobs Done', '$completed/$total', Icons.check_circle,
          total > 0 ? completed / total : 0.0, Colors.green)),
        const SizedBox(width: 10),
        Expanded(child: _kpiCard('Earnings', '₹$daily', Icons.payments, 0.0, _primary, subtitle: 'Weekly: ₹${_earnings['weekly'] ?? 0}')),
        const SizedBox(width: 10),
        Expanded(child: _kpiCard('Customers', '$_totalCustomers', Icons.people, 0.0, Colors.blue)),
      ]),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, double progress, Color color, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _secondary)),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
        if (subtitle != null) Text(subtitle, style: GoogleFonts.inter(fontSize: 9, color: Colors.grey)),
        if (progress > 0) ...[
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(color))),
        ],
      ]),
    );
  }

  Widget _buildDeviceHealth() {
    final online = _deviceHealth['online'] ?? 0;
    final offline = _deviceHealth['offline'] ?? 0;
    final healthy = _deviceHealth['healthy'] ?? 0;
    final warning = _deviceHealth['warning'] ?? 0;
    final critical = _deviceHealth['critical'] ?? 0;
    final total = _deviceHealth['total'] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Router Health', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _secondary)),
            Text('$total devices', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _healthDot(Colors.green, '$online', 'Online'),
            _healthDot(Colors.red, '$offline', 'Offline'),
            _healthDot(Colors.green.shade300, '$healthy', 'Healthy'),
            _healthDot(Colors.orange, '$warning', 'Warning'),
            _healthDot(Colors.red, '$critical', 'Critical'),
          ]),
        ]),
      ),
    );
  }

  Widget _healthDot(Color color, String count, String label) {
    return Column(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(height: 4),
      Text(count, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
      Text(label, style: GoogleFonts.inter(fontSize: 9, color: Colors.grey)),
    ]);
  }

  Widget _buildRouteStats() {
    final completed = _counts['completed'] ?? 0;
    final active = _counts['active'] ?? 0;
    final pending = _counts['pending'] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Today's Tasks", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _secondary)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _routeStat(Icons.check_circle, Colors.green, '$completed', 'Done'),
            Container(width: 1, height: 40, color: Colors.grey.shade200),
            _routeStat(Icons.engineering, Colors.blue, '$active', 'Active'),
            Container(width: 1, height: 40, color: Colors.grey.shade200),
            _routeStat(Icons.schedule, Colors.orange, '$pending', 'Pending'),
          ]),
        ]),
      ),
    );
  }

  Widget _routeStat(IconData icon, Color color, String count, String label) {
    return Column(children: [
      Icon(icon, color: color, size: 24),
      const SizedBox(height: 4),
      Text(count, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
      Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
    ]);
  }

  Widget _buildActiveJob(Map<String, dynamic> job) {
    final status = job['status']?.toString() ?? 'pending';
    final customerName = job['customer_name']?.toString() ?? 'Customer';
    final address = job['address']?.toString() ?? 'N/A';
    final type = job['type']?.toString() ?? 'Job';
    final jobId = job['id']?.toString() ?? '';
    Color sc = status == 'en_route' ? Colors.orange : (status == 'arrived' ? Colors.blue : Colors.grey);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveJobScreen(jobId: jobId))).then((_) => _fetchDashboard()),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            border: const Border(left: BorderSide(color: _primary, width: 4)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('🔥 Active Job', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _secondary)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(status.replaceAll('_', ' '), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: sc))),
            ]),
            const SizedBox(height: 8),
            Text('$type — $customerName', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
            Row(children: [
              const Icon(Icons.place, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(child: Text(address, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveJobScreen(jobId: jobId))).then((_) => _fetchDashboard()),
              style: ElevatedButton.styleFrom(backgroundColor: _secondary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Open Job', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _buildUrgentTickets() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.15))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.warning, color: Colors.red, size: 18),
            const SizedBox(width: 6),
            Text('Urgent Tickets (${_urgentTickets.length})', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.red)),
          ]),
          const SizedBox(height: 8),
          ..._urgentTickets.take(3).map((t) {
            final ticket = t as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                const Icon(Icons.confirmation_number, size: 14, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text('${ticket['title'] ?? 'Ticket'} — ${ticket['customer_name'] ?? ''}',
                  style: GoogleFonts.inter(fontSize: 12), overflow: TextOverflow.ellipsis)),
              ]),
            );
          }),
        ]),
      ),
    );
  }

  Widget _buildUpcomingJobs() {
    final upcoming = _todayJobs.where((j) => (j as Map)['status'] == 'pending').toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Upcoming (${upcoming.length})', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _secondary)),
        const SizedBox(height: 8),
        if (upcoming.isEmpty)
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(_todayJobs.isEmpty ? 'No jobs today' : 'All jobs active or done!', style: GoogleFonts.inter(color: Colors.grey, fontSize: 13))))
        else
          ...upcoming.map((job) {
            final j = job as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Row(children: [
                const Icon(Icons.schedule, color: Colors.orange, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${j['type'] ?? 'Job'} — ${j['customer_name'] ?? 'Customer'}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(j['address']?.toString() ?? '', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                ])),
              ]),
            );
          }),
      ]),
    );
  }
}
