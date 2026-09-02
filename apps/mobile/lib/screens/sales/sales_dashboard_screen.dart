import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fiberjet/services/sales_data_service.dart';
import 'sales_main_screen.dart';

class SalesDashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onTabSelect;

  const SalesDashboardScreen({super.key, this.onTabSelect});

  @override
  State<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends State<SalesDashboardScreen> {
  static const Color _navy = Color(0xFF1E3A8A);
  static const Color _primary = Color(0xFFFBBF24);
  static const Color _bgLight = Color(0xFFF3F4F6);
  static const Color _card = Colors.white;

  bool _isLoading = true;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    setState(() => _isLoading = true);
    final result = await SalesDataService.getDashboard();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.data != null) {
          _data = result.data as Map<String, dynamic>;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : RefreshIndicator(
                onRefresh: _fetchDashboard,
                color: _primary,
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildKpiRow(),
                            const SizedBox(height: 20),
                            _buildLeadsPipeline(),
                            const SizedBox(height: 20),
                            _buildRecentActivity(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final name = _data['name']?.toString() ?? 'Sales Rep';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning,'
        : hour < 17
            ? 'Good Afternoon,'
            : 'Good Evening,';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 32),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [BoxShadow(color: _navy.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.rocket_launch_rounded, color: _navy, size: 20),
                ),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  RichText(text: TextSpan(children: [
                    TextSpan(text: 'FIBER ', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    TextSpan(text: 'JET', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _primary)),
                  ])),
                  Text('Sales Rep Dashboard', style: GoogleFonts.inter(fontSize: 11, color: Colors.blue.shade200)),
                ]),
              ]),
              GestureDetector(
                onTap: () {
                  if (widget.onTabSelect != null) {
                    widget.onTabSelect!(4);
                  } else {
                    context.findAncestorStateOfType<SalesMainScreenState>()?.selectTab(4);
                  }
                },
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: _primary.withOpacity(0.2),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'S',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _primary,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: _navy, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(greeting, style: GoogleFonts.inter(fontSize: 13, color: Colors.blue.shade200)),
          Text(name, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildKpiRow() {
    final todayLeads = _data['today_leads']?.toString() ?? '0';
    final rank = _data['leaderboard_rank'];
    final rankStr = rank != null && rank != 0 ? '#$rank' : '--';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Transform.translate(
        offset: const Offset(0, -20),
        child: SizedBox(
          height: 96,
          child: Row(
            children: [
              Expanded(
                child: _kpiCard("Today's Leads", todayLeads, Icons.trending_up_rounded, Colors.green, _primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpiGradientCard('Leaderboard', rankStr, Icons.emoji_events_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNum(dynamic val) {
    final n = double.tryParse(val.toString()) ?? 0;
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);
  }

  Widget _kpiCard(String label, String value, IconData icon, Color iconColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 0.5)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(child: Text(value, style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.grey.shade800), overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
              child: Icon(icon, color: iconColor, size: 16),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _kpiGradientCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_primary, Color(0xFFFB923C)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.3), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _navy.withValues(alpha: 0.7), letterSpacing: 0.5)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(value, style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w700, color: _navy)),
            Icon(icon, color: _navy, size: 22),
          ]),
        ],
      ),
    );
  }

  Widget _buildLeadsPipeline() {
    final previewLeads = (_data['preview_leads'] as List?) ?? [];
    final pipeline = (_data['pipeline'] as Map?) ?? {};

    final stageColors = {
      'new': Colors.blue,
      'contacted': Colors.amber,
      'kyc_uploaded': Colors.purple,
      'approved': Colors.green,
      'installed': Colors.grey,
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Leads Pipeline', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
              GestureDetector(
                onTap: () {
                  if (widget.onTabSelect != null) {
                    widget.onTabSelect!(1);
                  } else {
                    context.findAncestorStateOfType<SalesMainScreenState>()?.selectTab(1);
                  }
                },
                child: Text(
                  'View All',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: _navy),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final stages = ['new', 'contacted', 'kyc_uploaded', 'approved', 'installed'];
              final stage = stages[i];
              final count = pipeline[stage]?.toString() ?? '0';
              
              // Find matching lead in previewLeads
              final leadMap = previewLeads.firstWhere(
                (l) => l['stage'] == stage,
                orElse: () => null,
              );
              
              final name = leadMap != null ? (leadMap['customer_name']?.toString() ?? 'Unknown') : 'No Leads';
              final phone = leadMap != null ? (leadMap['phone']?.toString() ?? '') : 'No active leads';
              final timeStr = leadMap != null ? _timeAgo(leadMap['created_at']) : '';

              final stageLabel = stage.replaceAll('_', ' ');
              final color = stageColors[stage] ?? Colors.grey;

              return _pipelineColumn(
                '${stageLabel[0].toUpperCase()}${stageLabel.substring(1)} ($count)',
                color,
                name,
                phone,
                timeStr,
              );
            },
          ),
        ),
      ],
    );
  }

  String _timeAgo(dynamic dt) {
    if (dt == null) return '';
    try {
      final date = DateTime.parse(dt.toString());
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (_) {
      return '';
    }
  }

  Widget _pipelineColumn(String stage, Color color, String name, String plan, String detail) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(stage, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 0.5))),
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ]),
          const SizedBox(height: 10),
          Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          Text(plan, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
          const Spacer(),
          if (detail.isNotEmpty)
            Row(children: [
              const Icon(Icons.schedule, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text(detail, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
            ])
          else
            const SizedBox(height: 13),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final activities = (_data['recent_activity'] as List?) ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Activity', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
          const SizedBox(height: 12),
          if (activities.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: Center(child: Text('No recent activity', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey))),
            )
          else
            Container(
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: Column(children: [
                for (int i = 0; i < activities.length && i < 5; i++) ...[
                  _activityTile(
                    _activityIcon(activities[i]['action']),
                    _activityColor(activities[i]['action']),
                    activities[i]['action']?.toString() ?? 'Action',
                    activities[i]['target_table']?.toString() ?? '',
                    _timeAgo(activities[i]['created_at']),
                  ),
                  if (i < activities.length - 1 && i < 4) Divider(height: 1, color: Colors.grey.shade200),
                ],
              ]),
            ),
        ],
      ),
    );
  }

  IconData _activityIcon(dynamic action) {
    final a = action?.toString().toLowerCase() ?? '';
    if (a.contains('create') || a.contains('insert')) return Icons.person_add;
    if (a.contains('update') || a.contains('edit')) return Icons.edit;
    if (a.contains('upload')) return Icons.upload_file;
    if (a.contains('complete')) return Icons.check_circle;
    return Icons.history;
  }

  Color _activityColor(dynamic action) {
    final a = action?.toString().toLowerCase() ?? '';
    if (a.contains('create') || a.contains('insert')) return Colors.blue;
    if (a.contains('upload')) return Colors.purple;
    if (a.contains('complete')) return Colors.green;
    return Colors.grey;
  }

  Widget _activityTile(IconData icon, Color color, String title, String subtitle, String time) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        CircleAvatar(radius: 20, backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade800), overflow: TextOverflow.ellipsis)),
              Text(time, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
            ]),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
          ]),
        ),
      ]),
    );
  }
}
