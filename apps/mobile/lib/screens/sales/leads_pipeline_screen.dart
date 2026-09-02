import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fiberjet/services/sales_data_service.dart';
import 'package:fiberjet/screens/sales/lead_comments_screen.dart';

class LeadsPipelineScreen extends StatefulWidget {
  const LeadsPipelineScreen({super.key});

  @override
  State<LeadsPipelineScreen> createState() => _LeadsPipelineScreenState();
}

class _LeadsPipelineScreenState extends State<LeadsPipelineScreen>
    with SingleTickerProviderStateMixin {
  static const Color _navy = Color(0xFF1E3A8A);
  static const Color _primary = Color(0xFFFBBF24);
  static const Color _bgLight = Color(0xFFF3F4F6);
  static const Color _card = Colors.white;

  bool _isLoading = true;
  List<dynamic> _allLeads = [];
  int _selectedStageIndex = 0;

  static const _stages = [
    'all',
    'new',
    'contacted',
    'kyc_uploaded',
    'approved',
    'installed',
  ];
  static const _stageLabels = {
    'all': 'All',
    'new': 'New',
    'contacted': 'Contacted',
    'kyc_uploaded': 'KYC Uploaded',
    'approved': 'Approved',
    'installed': 'Installed',
  };
  static const _stageIcons = {
    'all': Icons.apps_rounded,
    'new': Icons.fiber_new_rounded,
    'contacted': Icons.phone_in_talk_rounded,
    'kyc_uploaded': Icons.upload_file_rounded,
    'approved': Icons.verified_rounded,
    'installed': Icons.check_circle_rounded,
  };
  static final _stageColors = {
    'all': Colors.grey.shade700,
    'new': const Color(0xFF3B82F6),
    'contacted': const Color(0xFFF59E0B),
    'kyc_uploaded': const Color(0xFF8B5CF6),
    'approved': const Color(0xFF10B981),
    'installed': const Color(0xFF6B7280),
  };

  final ScrollController _chipScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchLeads();
  }

  @override
  void dispose() {
    _chipScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeads() async {
    setState(() => _isLoading = true);
    final result = await SalesDataService.getLeads();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.data != null) {
          final data = result.data as Map<String, dynamic>;
          _allLeads = (data['leads'] as List?) ?? [];
        }
      });
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupByStage() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final stage in _stages) {
      grouped[stage] = [];
    }
    for (final lead in _allLeads) {
      final m = lead as Map<String, dynamic>;
      final stage = m['stage']?.toString() ?? 'new';
      grouped.putIfAbsent(stage, () => []);
      grouped[stage]!.add(m);
      grouped['all']!.add(m);
    }
    return grouped;
  }

  List<Map<String, dynamic>> _getFilteredLeads() {
    final grouped = _groupByStage();
    final stage = _stages[_selectedStageIndex];
    return grouped[stage] ?? [];
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
                onRefresh: _fetchLeads,
                color: _primary,
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildStageChips(),
                    _buildPipelineProgress(),
                    Expanded(child: _buildLeadsList()),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final grouped = _groupByStage();
    final totalPipeline = _allLeads.length;
    final pendingKyc = grouped['kyc_uploaded']?.length ?? 0;
    final newToday = _allLeads.where((l) {
      try {
        final created = DateTime.parse(l['created_at'].toString());
        final now = DateTime.now();
        return created.day == now.day &&
            created.month == now.month &&
            created.year == now.year;
      } catch (_) {
        return false;
      }
    }).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.view_kanban_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leads Pipeline',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Track and manage your leads',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.blue.shade200,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _headerStat('Total', '$totalPipeline', Icons.people_alt_rounded),
              const SizedBox(width: 12),
              _headerStat(
                'Pending KYC',
                '$pendingKyc',
                Icons.pending_actions_rounded,
              ),
              const SizedBox(width: 12),
              _headerStat('New Today', '+$newToday', Icons.trending_up_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: _primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade200,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageChips() {
    final grouped = _groupByStage();

    return Container(
      color: _bgLight,
      child: SingleChildScrollView(
        controller: _chipScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: List.generate(_stages.length, (i) {
            final stage = _stages[i];
            final label = _stageLabels[stage] ?? stage;
            final count = grouped[stage]?.length ?? 0;
            final isSelected = _selectedStageIndex == i;
            final color = _stageColors[stage] ?? Colors.grey;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedStageIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? color : _card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : Colors.grey.shade300,
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _stageIcons[stage] ?? Icons.circle,
                        size: 14,
                        color: isSelected ? Colors.white : color,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildPipelineProgress() {
    final grouped = _groupByStage();
    final total = _allLeads.isEmpty ? 1 : _allLeads.length;

    final progressStages = _stages.where((s) => s != 'all').toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: progressStages.map((stage) {
                  final count = grouped[stage]?.length ?? 0;
                  final fraction = count / total;
                  final color = _stageColors[stage] ?? Colors.grey;
                  return Expanded(
                    flex: (fraction * 1000).round().clamp(1, 1000),
                    child: Container(
                      color: count > 0 ? color : Colors.grey.shade200,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 6),

          Row(
            children: progressStages.map((stage) {
              final count = grouped[stage]?.length ?? 0;
              final color = _stageColors[stage] ?? Colors.grey;
              final label = _stageLabels[stage] ?? stage;
              return Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '$count',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
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
    );
  }

  Widget _buildLeadsList() {
    final leads = _getFilteredLeads();
    final stage = _stages[_selectedStageIndex];
    final stageLabel = _stageLabels[stage] ?? stage;

    if (leads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _stageIcons[stage] ?? Icons.inbox_rounded,
                size: 40,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No leads in "$stageLabel"',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Leads at this stage will appear here',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: leads.length,
      itemBuilder: (_, i) => _leadCard(leads[i]),
    );
  }

  Widget _leadCard(Map<String, dynamic> lead) {
    final name = lead['customer_name']?.toString() ?? 'Unknown';
    final phone = lead['phone']?.toString() ?? '';
    final score = lead['score']?.toString().toUpperCase() ?? '';
    final leadId = lead['id']?.toString() ?? '';
    final stage = lead['stage']?.toString() ?? 'new';
    final stageLabel = _stageLabels[stage] ?? stage;
    final stageColor = _stageColors[stage] ?? Colors.grey;
    final timeStr = _timeAgo(lead['created_at']);

    Color scoreBadgeColor;
    IconData scoreIcon;
    switch (score.toLowerCase()) {
      case 'hot':
        scoreBadgeColor = Colors.red;
        scoreIcon = Icons.local_fire_department_rounded;
        break;
      case 'warm':
        scoreBadgeColor = const Color(0xFFF59E0B);
        scoreIcon = Icons.wb_sunny_rounded;
        break;
      default:
        scoreBadgeColor = Colors.blue.shade300;
        scoreIcon = Icons.ac_unit_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  LeadCommentsScreen(leadId: leadId, leadName: name),
            ),
          ).then((_) => _fetchLeads());
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: stageColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: stageColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (phone.isNotEmpty)
                          Text(
                            phone,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (score.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scoreBadgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: scoreBadgeColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(scoreIcon, size: 12, color: scoreBadgeColor),
                          const SizedBox(width: 4),
                          Text(
                            score,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: scoreBadgeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              Container(height: 1, color: Colors.grey.shade100),
              const SizedBox(height: 12),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: stageColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: stageColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          stageLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: stageColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    timeStr,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const Spacer(),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _navy.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Details',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: _navy,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
}
