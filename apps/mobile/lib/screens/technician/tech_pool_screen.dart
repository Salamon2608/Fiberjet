import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fiberjet/services/tech_data_service.dart';

class TechPoolScreen extends StatefulWidget {
  const TechPoolScreen({super.key});

  @override
  State<TechPoolScreen> createState() => _TechPoolScreenState();
}

class _TechPoolScreenState extends State<TechPoolScreen> with SingleTickerProviderStateMixin {
  static const Color _primaryGold = Color(0xFFFBBF24);
  static const Color _navyBlue = Color(0xFF1E3A8A);
  static const Color _bgLight = Color(0xFFF3F4F6);
  static const Color _slateText = Color(0xFF475569);

  bool _isLoading = true;
  List<dynamic> _allPoolItems = [];
  List<dynamic> _filteredItems = [];
  String _activeFilter = 'all'; // 'all', 'job', 'complaint'
  String? _claimingTaskId;

  @override
  void initState() {
    super.initState();
    _fetchPool();
  }

  Future<void> _fetchPool() async {
    setState(() => _isLoading = true);
    try {
      final futures = await Future.wait([
        TechDataService.getJobPool(),
        TechDataService.getJobs(status: 'completed'),
      ]);

      final poolRes = futures[0];
      final compRes = futures[1];

      List<dynamic> combinedItems = [];

      if (poolRes.success && poolRes.data != null) {
        final data = poolRes.data as Map<String, dynamic>;
        combinedItems.addAll((data['pool'] as List?) ?? []);
      }

      if (compRes.success && compRes.data != null) {
        final data = compRes.data as Map<String, dynamic>;
        final jobs = (data['jobs'] as List?) ?? [];
        final completedItems = jobs.map((j) {
          final map = j as Map<String, dynamic>;
          return {
            'id': map['id'],
            'title': 'Completed Installation',
            'category': map['type'],
            'description': 'Installation successfully completed.',
            'status': map['status'],
            'customer_name': map['customer_name'],
            'customer_phone': map['customer_phone'],
            'address': map['address'],
            'scheduled_at': map['scheduled_at']?.toString(),
            'created_at': map['created_at']?.toString(),
            'type': 'completed',
          };
        }).toList();
        combinedItems.addAll(completedItems);
      }

      if (mounted) {
        setState(() {
          _allPoolItems = combinedItems;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('An unexpected error occurred');
      }
    }
  }

  void _applyFilter() {
    if (_activeFilter == 'all') {
      _filteredItems = _allPoolItems.where((item) => item['type'] != 'completed').toList();
    } else {
      _filteredItems = _allPoolItems.where((item) => item['type'] == _activeFilter).toList();
    }
  }

  void _changeFilter(String filter) {
    setState(() {
      _activeFilter = filter;
      _applyFilter();
    });
  }

  Future<void> _claimTask(String type, String id, String title) async {
    // Show confirmation dialog before claiming
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Claim Task', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _navyBlue)),
        content: Text('Are you sure you want to accept this $type task?\n\n"$title"', style: GoogleFonts.inter(color: _slateText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _navyBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Accept', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _claimingTaskId = id);

    try {
      final res = await TechDataService.claimPoolTask(taskType: type, taskId: id);
      setState(() => _claimingTaskId = null);

      if (res.success) {
        _showSuccessDialog(type, title);
        _fetchPool(); // Refresh pool
      } else {
        // If conflict (e.g. claimed by someone else), show specialized warning
        if (res.message.contains('already been claimed')) {
          _showCollisionDialog(title);
        } else {
          _showSnackBar(res.message);
        }
        _fetchPool(); // Refresh to get correct state
      }
    } catch (e) {
      setState(() => _claimingTaskId = null);
      _showSnackBar('Error claiming task: $e');
    }
  }

  void _showSuccessDialog(String type, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 54),
            ),
            const SizedBox(height: 20),
            Text(
              'Task Claimed!',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: _navyBlue),
            ),
            const SizedBox(height: 8),
            Text(
              'Successfully assigned to you. You can now manage and start this $type from your dashboard.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: _slateText),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navyBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Awesome', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCollisionDialog(String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.flash_on_rounded, color: Colors.orange, size: 54),
            ),
            const SizedBox(height: 20),
            Text(
              'Already Claimed!',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: _navyBlue),
            ),
            const SizedBox(height: 8),
            Text(
              'Ah! Another technician just claimed this task a split-second before you.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: _slateText),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Refresh Pool', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
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

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateStr;
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
            _buildPremiumHeader(),
            _buildGlassFilterTabs(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchPool,
                color: _navyBlue,
                child: _isLoading
                    ? _buildShimmerLoading()
                    : _filteredItems.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _filteredItems.length,
                            itemBuilder: (ctx, index) {
                              final item = _filteredItems[index];
                              return _buildPoolCard(item);
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
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
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task Pool',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Claim open jobs and support tickets instantly',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.blue.shade100,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _fetchPool,
                icon: const Icon(Icons.autorenew_rounded, color: Colors.white),
                tooltip: 'Refresh tasks',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassFilterTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _filterTabButton('all', 'All Tasks', Icons.workspaces_rounded)),
          Expanded(child: _filterTabButton('job', 'Installations', Icons.engineering_rounded)),
          Expanded(child: _filterTabButton('complaint', 'Tickets', Icons.support_agent_rounded)),
          Expanded(child: _filterTabButton('completed', 'Completed', Icons.task_alt_rounded)),
        ],
      ),
    );
  }

  Widget _filterTabButton(String key, String title, IconData icon) {
    final isActive = _activeFilter == key;
    return GestureDetector(
      onTap: () => _changeFilter(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isActive ? _navyBlue : Colors.transparent,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: _navyBlue.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : _slateText,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? Colors.white : _slateText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoolCard(Map<String, dynamic> item) {
    final type = item['type'] as String;
    final isJob = type == 'job';
    final isCompleted = type == 'completed';
    final id = item['id'].toString();
    final title = item['title']?.toString() ?? (isJob ? 'Installation' : 'Support Ticket');
    final desc = item['description']?.toString() ?? '';
    final customer = item['customer_name']?.toString() ?? 'Customer';
    final phone = item['customer_phone']?.toString() ?? '';
    final created = item['created_at']?.toString();
    final address = item['address']?.toString();
    final scheduled = item['scheduled_at']?.toString();

    final cardAccentColor = isCompleted ? Colors.green : (isJob ? Colors.teal : Colors.orange.shade800);
    final isClaimingThis = _claimingTaskId == id;
    final isAssignedToMe = item['assigned_to'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: cardAccentColor, width: 6),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge & Date Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cardAccentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isCompleted ? '✅ COMPLETED' : (isJob ? '🛠️ INSTALLATION' : '🎫 COMPLAINT TICKET'),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: cardAccentColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Text(
                    'Added ${_formatDateTime(created)}',
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _navyBlue,
                ),
              ),
              const SizedBox(height: 6),

              // Description
              Text(
                desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12, color: _slateText, height: 1.4),
              ),
              const SizedBox(height: 12),

              const Divider(height: 1),
              const SizedBox(height: 12),

              // Info grid (Customer details, Scheduled time, Address)
              Row(
                children: [
                  const Icon(Icons.person_rounded, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$customer (${phone.isNotEmpty ? phone : 'No phone'})',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _slateText),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              if (isJob && scheduled != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.event_note_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Scheduled: ${_formatDateTime(scheduled)}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blue.shade800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              if (address != null && address.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2.0),
                      child: Icon(Icons.place_rounded, size: 14, color: Colors.grey),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, color: _slateText),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Action button
              if (!isCompleted)
                if (isAssignedToMe)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Assigned to You (Check Dashboard)',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isClaimingThis ? null : () => _claimTask(type, id, title),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cardAccentColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: cardAccentColor.withValues(alpha: 0.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: isClaimingThis
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_task_rounded, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  isJob ? 'Accept & Claim Installation' : 'Claim Support Ticket',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                                ),
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

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.55,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.celebration_rounded, color: _primaryGold, size: 68),
            ),
            const SizedBox(height: 24),
            Text(
              'Task Pool is Clear!',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: _navyBlue),
            ),
            const SizedBox(height: 8),
            Text(
              'Amazing! All complaints have been claimed, and all installations are assigned. Check back later or swipe down to refresh.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: _slateText, height: 1.5),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _fetchPool,
              icon: const Icon(Icons.refresh_rounded, color: _navyBlue),
              label: Text(
                'Refresh Now',
                style: GoogleFonts.inter(color: _navyBlue, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 3,
      itemBuilder: (ctx, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(width: 80, height: 16, color: Colors.grey.shade100),
                  Container(width: 100, height: 12, color: Colors.grey.shade100),
                ],
              ),
              const SizedBox(height: 16),
              Container(width: 200, height: 18, color: Colors.grey.shade200),
              const SizedBox(height: 8),
              Container(width: double.infinity, height: 14, color: Colors.grey.shade100),
              const SizedBox(height: 4),
              Container(width: 140, height: 14, color: Colors.grey.shade100),
              const Spacer(),
              Container(width: double.infinity, height: 40, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12))),
            ],
          ),
        );
      },
    );
  }
}
