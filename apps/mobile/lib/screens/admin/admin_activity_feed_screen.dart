import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fiberjet/services/admin_data_service.dart';

class AdminActivityFeedScreen extends StatefulWidget {
  const AdminActivityFeedScreen({super.key});

  @override
  State<AdminActivityFeedScreen> createState() => _AdminActivityFeedScreenState();
}

class _AdminActivityFeedScreenState extends State<AdminActivityFeedScreen> {
  static const Color _navyBlue = Color(0xFF1E3A8A);
  static const Color _bgLight = Color(0xFFF8FAFC);
  static const Color _slateText = Color(0xFF475569);

  bool _isLoading = true;
  List<dynamic> _allActivities = [];
  List<dynamic> _filteredActivities = [];
  String _searchQuery = '';
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _fetchActivities();
  }

  Future<void> _fetchActivities() async {
    setState(() => _isLoading = true);
    try {
      final res = await AdminDataService.getTechnicianActivities();
      if (res.success && res.data != null) {
        final data = res.data as Map<String, dynamic>;
        setState(() {
          _allActivities = (data['activities'] as List?) ?? [];
          _applyFilters();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showSnackBar(res.message);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('An unexpected error occurred: $e');
    }
  }

  void _applyFilters() {
    if (_searchQuery.isEmpty) {
      _filteredActivities = List.from(_allActivities);
    } else {
      _filteredActivities = _allActivities.where((act) {
        final name = (act['technician_name'] ?? '').toString().toLowerCase();
        final action = (act['action'] ?? '').toString().toLowerCase();
        final targetTable = (act['target_table'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || action.contains(query) || targetTable.contains(query);
      }).toList();
    }
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val;
      _applyFilters();
    });
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        backgroundColor: _navyBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Beautiful helper to calculate relative time
  String _getRelativeTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inSeconds < 60) {
        return 'Just now';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        return DateFormat('dd MMM, hh:mm a').format(dt);
      }
    } catch (_) {
      return dateStr;
    }
  }

  // Get description text, icon and accent color based on action type
  _ActivityStyle _getActivityStyle(String action, Map<String, dynamic>? newValues) {
    final status = newValues?['status']?.toString() ?? '';

    switch (action) {
      case 'claim_job':
        return _ActivityStyle(
          description: 'claimed an installation setup',
          icon: Icons.add_task_rounded,
          color: Colors.blue.shade700,
          bgLight: Colors.blue.shade50,
        );
      case 'claim_complaint':
        return _ActivityStyle(
          description: 'claimed a support complaint ticket',
          icon: Icons.assignment_turned_in_rounded,
          color: Colors.indigo.shade700,
          bgLight: Colors.indigo.shade50,
        );
      case 'update_job_status':
        if (status == 'completed') {
          return _ActivityStyle(
            description: 'completed installation setup',
            icon: Icons.verified_rounded,
            color: Colors.green.shade700,
            bgLight: Colors.green.shade50,
          );
        } else if (status == 'en_route') {
          return _ActivityStyle(
            description: 'is en-route to installation address',
            icon: Icons.directions_car_rounded,
            color: Colors.orange.shade700,
            bgLight: Colors.orange.shade50,
          );
        } else if (status == 'arrived') {
          return _ActivityStyle(
            description: 'arrived at customer location',
            icon: Icons.place_rounded,
            color: Colors.teal.shade700,
            bgLight: Colors.teal.shade50,
          );
        } else {
          return _ActivityStyle(
            description: 'updated installation status to ${status.replaceAll('_', ' ')}',
            icon: Icons.sync_rounded,
            color: Colors.blueGrey.shade700,
            bgLight: Colors.blueGrey.shade50,
          );
        }
      case 'update_complaint_status':
        if (status == 'resolved') {
          return _ActivityStyle(
            description: 'resolved support ticket',
            icon: Icons.check_circle_rounded,
            color: Colors.green.shade700,
            bgLight: Colors.green.shade50,
          );
        } else if (status == 'in_progress') {
          return _ActivityStyle(
            description: 'started resolving complaint',
            icon: Icons.pending_rounded,
            color: Colors.orange.shade700,
            bgLight: Colors.orange.shade50,
          );
        } else {
          return _ActivityStyle(
            description: 'updated ticket status to ${status.replaceAll('_', ' ')}',
            icon: Icons.sync_rounded,
            color: Colors.blueGrey.shade700,
            bgLight: Colors.blueGrey.shade50,
          );
        }
      default:
        return _ActivityStyle(
          description: 'performed action: $action',
          icon: Icons.info_outline_rounded,
          color: Colors.blueGrey,
          bgLight: Colors.grey.shade100,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildGradientHeader(),
            _buildSearchAndFilters(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchActivities,
                color: _navyBlue,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: _navyBlue))
                    : _filteredActivities.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            itemCount: _filteredActivities.length,
                            itemBuilder: (ctx, index) {
                              final item = _filteredActivities[index];
                              return _buildTimelineItem(item, index);
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_navyBlue, Colors.blue.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Technician Operations',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Live activity feed and dispatch logs',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.blue.shade100,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: _fetchActivities,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Reload logs',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextField(
        onChanged: _onSearchChanged,
        style: GoogleFonts.inter(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by technician, action, or table...',
          hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _navyBlue, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> item, int index) {
    final techName = item['technician_name']?.toString() ?? 'Technician';
    final action = item['action']?.toString() ?? '';
    final newValues = item['new_values'] as Map<String, dynamic>?;
    final created = item['created_at']?.toString();
    final targetTable = item['target_table']?.toString() ?? '';
    final targetId = item['target_id']?.toString() ?? '';

    final style = _getActivityStyle(action, newValues);
    final isExpanded = _expandedIndex == index;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Timeline line and beautiful circular icon
        Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: style.bgLight,
                shape: BoxShape.circle,
                border: Border.all(color: style.color.withValues(alpha: 0.15), width: 1.5),
              ),
              child: Icon(style.icon, color: style.color, size: 18),
            ),
            // Timeline joining vertical line
            if (index < _filteredActivities.length - 1)
              Container(
                width: 2.5,
                height: isExpanded ? 180 : 76,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [style.color.withValues(alpha: 0.4), Colors.grey.shade300],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 14),

        // Right Column: Timeline details card
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? null : index;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isExpanded ? style.color.withValues(alpha: 0.25) : Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(fontSize: 13, height: 1.3),
                            children: [
                              TextSpan(
                                text: techName,
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _navyBlue),
                              ),
                              const TextSpan(text: ' '),
                              TextSpan(
                                text: style.description,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: _slateText),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getRelativeTime(created),
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          targetTable.toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ID: $targetId',
                          style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Expandable JSON/Metadata Detail Block
                  if (isExpanded) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Text(
                      'Operation Details',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _navyBlue),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade900,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (newValues != null)
                            ...newValues.entries.map((e) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.white70),
                                    children: [
                                      TextSpan(text: '${e.key}: ', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                                      TextSpan(text: '${e.value}'),
                                    ],
                                  ),
                                ),
                              );
                            })
                          else
                            Text(
                              'No extra values recorded.',
                              style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.white54),
                            ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.white70),
                              children: [
                                const TextSpan(text: 'timestamp: ', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                                TextSpan(text: created ?? 'N/A'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_toggle_off_rounded, color: Colors.blue, size: 68),
            ),
            const SizedBox(height: 24),
            Text(
              'No Activities Found',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: _navyBlue),
            ),
            const SizedBox(height: 8),
            Text(
              'No technician activities have been logged yet or no logs match your filter.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: _slateText, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityStyle {
  final String description;
  final IconData icon;
  final Color color;
  final Color bgLight;

  _ActivityStyle({
    required this.description,
    required this.icon,
    required this.color,
    required this.bgLight,
  });
}
