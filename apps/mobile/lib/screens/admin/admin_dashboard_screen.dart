import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fiberjet/services/admin_data_service.dart';
import 'package:fiberjet/screens/admin/user_approval_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const Color _navy = Color(0xFF0A2540);
  static const Color _primary = Color(0xFFF9B515);
  static const Color _surfaceDark = Color(0xFF1E293B);
  static const Color _bgDark = Color(0xFF0F172A);

  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchDashboard() async {
    final result = await AdminDataService.getDashboard();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success) {
          _dashboardData = result.data;
        } else {
          _error = result.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bgDark,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: _bgDark,
        body: Center(
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Fixed Header ──
            _buildHeader(),
            // ── Scrollable Content ──
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBusinessKpis(),
                    _buildCriticalAlert(),
                    _buildActiveUsersChart(),
                    _buildRevenueChart(),
                    _buildPendingApprovals(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _bgDark.withOpacity(0.9),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              color: _navy,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fiber Jet',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                'Admin Console',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          Stack(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white70,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: _bgDark, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Business KPIs ──
  Widget _buildBusinessKpis() {
    final users = _dashboardData?['users'] ?? {};
    final revenue = _dashboardData?['revenue'] ?? {};
    final tech = _dashboardData?['technicians'] ?? {};

    final totalActive = users['active']?.toString() ?? '0';
    final newUsers = users['new_this_week']?.toString() ?? '0';
    final mrr = '\$${revenue['mrr']?.toString() ?? '0'}';
    final efficiency = '${tech['efficiency']?.toString() ?? '0'}%';
    final netProfit = '\$${revenue['net_profit']?.toString() ?? '0'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  Icons.router_rounded,
                  Colors.blue,
                  totalActive,
                  'Active Connections',
                  '+$newUsers this week',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpiCard(
                  Icons.payments_rounded,
                  Colors.amber,
                  mrr,
                  'Monthly Revenue',
                  '',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  Icons.analytics_rounded,
                  Colors.green,
                  netProfit,
                  'Net Profit',
                  '',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpiCard(
                  Icons.handyman_rounded,
                  Colors.purpleAccent,
                  efficiency,
                  'Tech Efficiency',
                  '',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(
    IconData icon,
    Color color,
    String value,
    String label,
    String change,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Row(
                children: [
                  if (change.isNotEmpty) ...[
                    Text(
                      change,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.greenAccent,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_upward,
                      size: 12,
                      color: Colors.greenAccent,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  // ── Critical Alert ──
  Widget _buildCriticalAlert() {
    final complaints = _dashboardData?['complaints'] ?? {};
    final openComplaints = complaints['open'] ?? 0;
    final breakdown =
        complaints['categories_breakdown'] as Map<String, dynamic>? ?? {};

    if (openComplaints == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Complaints',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$openComplaints open tickets need attention',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('View'),
                ),
              ],
            ),
            if (breakdown.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: breakdown.entries
                    .map(
                      (e) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${e.key}: ${e.value}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Active Users Growth Chart ──
  Widget _buildActiveUsersChart() {
    final chartData = _dashboardData?['charts']?['user_growth'] as List? ?? [];
    final List<double> data = chartData.isNotEmpty
        ? chartData
              .map((e) => double.tryParse(e['value']?.toString() ?? '0') ?? 0.0)
              .toList()
        : [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    final List<String> labels = chartData.isNotEmpty
        ? chartData.map((e) => e['label']?.toString() ?? '').toList()
        : ['', '', '', '', '', ''];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Users Growth',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Last 6 Months',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (chartData.isEmpty)
              const SizedBox(
                height: 160,
                child: Center(
                  child: Text(
                    'Not enough data to display chart',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              )
            else
              SizedBox(
                height: 160,
                child: CustomPaint(
                  size: const Size(double.infinity, 160),
                  painter: _LineChartPainter(data: data, labels: labels),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Revenue Chart ──
  Widget _buildRevenueChart() {
    final chartData =
        _dashboardData?['charts']?['revenue_history'] as List? ?? [];
    final List<double> data = chartData.isNotEmpty
        ? chartData
              .map((e) => double.tryParse(e['value']?.toString() ?? '0') ?? 0.0)
              .toList()
        : [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    final List<String> labels = chartData.isNotEmpty
        ? chartData.map((e) => e['label']?.toString() ?? '').toList()
        : ['', '', '', '', '', '', ''];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Weekly Revenue',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Last 7 Days',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (chartData.isEmpty)
              const SizedBox(
                height: 160,
                child: Center(
                  child: Text(
                    'Not enough data to display chart',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              )
            else
              SizedBox(
                height: 160,
                child: CustomPaint(
                  size: const Size(double.infinity, 160),
                  painter: _BarChartPainter(data: data, labels: labels),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Pending Approvals ──
  Widget _buildPendingApprovals() {
    final pendingApprovals =
        (_dashboardData?['pending_approvals'] as List?) ?? [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pending Approvals',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (pendingApprovals.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    // This assumes the parent is AdminMainScreen and we want to switch tabs
                    // However, we can also push the screen if preferred.
                    // Given the current structure, pushing is safer.
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserApprovalScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'View All',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (pendingApprovals.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: _surfaceDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Center(
                child: Text(
                  'No pending approvals.',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
                ),
              ),
            )
          else
            ...pendingApprovals.map((approval) {
              final name = approval['name'] as String? ?? 'Unknown';
              final role = approval['role'] as String? ?? 'user';

              IconData badgeIcon;
              Color badgeColor;
              String displayRole;

              if (role.toLowerCase().contains('tech')) {
                badgeIcon = Icons.engineering_rounded;
                badgeColor = Colors.blue;
                displayRole = 'Technician';
              } else if (role.toLowerCase().contains('sales')) {
                badgeIcon = Icons.badge_rounded;
                badgeColor = Colors.purple;
                displayRole = 'Sales Rep';
              } else {
                badgeIcon = Icons.person_rounded;
                badgeColor = Colors.green;
                displayRole = 'Customer';
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _approvalTile(name, displayRole, badgeIcon, badgeColor),
              );
            }),
        ],
      ),
    );
  }

  Widget _approvalTile(
    String name,
    String role,
    IconData badge,
    Color badgeColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade700,
                child: Text(
                  name[0],
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: _surfaceDark,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(badge, size: 12, color: badgeColor),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  role,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
          _actionBtn(Icons.check, Colors.green),
          const SizedBox(width: 6),
          _actionBtn(Icons.close, Colors.red),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

// ── Custom Line Chart Painter ──
class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;

  _LineChartPainter({required this.data, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = data.isEmpty ? 1.0 : data.reduce((a, b) => a > b ? a : b);
    final safeMax = maxVal == 0 ? 1.0 : maxVal;
    final paint = Paint()
      ..color = const Color(0xFFF9B515)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()..style = PaintingStyle.fill;

    final points = <Offset>[];
    final chartH = size.height - 24;

    for (int i = 0; i < data.length; i++) {
      final x = data.length > 1
          ? i * (size.width / (data.length - 1))
          : size.width / 2;
      final y = chartH - (data[i] / safeMax) * chartH;
      points.add(Offset(x, y));
    }

    // Gradient fill
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final cp1 = Offset(
        (points[i - 1].dx + points[i].dx) / 2,
        points[i - 1].dy,
      );
      final cp2 = Offset((points[i - 1].dx + points[i].dx) / 2, points[i].dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i].dx, points[i].dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    fillPaint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x80F9B515), Color(0x00F9B515)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Points
    final dotPaint = Paint()..color = const Color(0xFFF9B515);
    final dotBorder = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final p in points) {
      canvas.drawCircle(p, 4, dotPaint);
      canvas.drawCircle(p, 4, dotBorder);
    }

    // Labels
    for (int i = 0; i < labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(points[i].dx - tp.width / 2, size.height - 14));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Custom Bar Chart Painter ──
class _BarChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;

  _BarChartPainter({required this.data, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = data.isEmpty ? 1.0 : data.reduce((a, b) => a > b ? a : b);
    final safeMax = maxVal == 0 ? 1.0 : maxVal;
    final barWidth = 14.0;
    final spacing = size.width / data.length;
    final chartH = size.height - 24;

    for (int i = 0; i < data.length; i++) {
      final x = spacing * i + spacing / 2 - barWidth / 2;
      final h = (data[i] / safeMax) * chartH;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, chartH - h, barWidth, h),
        const Radius.circular(4),
      );

      final paint = Paint()..color = const Color(0xFF1E3A8A);
      canvas.drawRRect(rect, paint);

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(spacing * i + spacing / 2 - tp.width / 2, size.height - 14),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
