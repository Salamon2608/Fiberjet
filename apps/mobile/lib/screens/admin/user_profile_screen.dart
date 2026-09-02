import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fiberjet/services/admin_data_service.dart';
import 'package:fiberjet/services/api_service.dart';

class UserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _isLoading = true;
  List<dynamic> _auditLogs = [];
  List<dynamic> _bills = [];
  Map<String, dynamic>? _linkedModem;
  Map<String, dynamic>? _fullUser;

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final day = dt.day.toString().padLeft(2, '0');
      final month = months[dt.month - 1];
      final year = dt.year;
      
      int hour = dt.hour;
      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      
      return '$day $month $year, ${hour.toString().padLeft(2, '0')}:$minute $period';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  void initState() {
    super.initState();
    final roleStr = (widget.user['role']?.toString() ?? '').toLowerCase();
    final isTech = roleStr.contains('tech');
    final isSales = roleStr.contains('sales');
    if (!isTech && !isSales) {
      _tabController = TabController(length: 3, vsync: this);
    }
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    setState(() => _isLoading = true);
    final userRes = await AdminDataService.getUser(widget.user['id']);
    
    Map<String, dynamic>? fullUserMap;
    if (userRes.success && userRes.data != null) {
      fullUserMap = userRes.data as Map<String, dynamic>?;
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${userRes.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
    
    final roleStr = fullUserMap?['role'] ?? widget.user['role'];
    final roleLower = (roleStr?.toString() ?? '').toLowerCase();
    final isTech = roleLower.contains('tech');
    final isSales = roleLower.contains('sales');

    ApiResult? auditRes;
    ApiResult? billsRes;
    ApiResult? modemRes;

    if (!isTech && !isSales) {
      auditRes = await AdminDataService.getUserAuditLogs(widget.user['id']);
      billsRes = await AdminDataService.getUserBills(widget.user['id']);
      modemRes = await AdminDataService.getModem(widget.user['id']);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _fullUser = fullUserMap;
        if (auditRes != null && auditRes.success) _auditLogs = auditRes.data ?? [];
        if (billsRes != null && billsRes.success) _bills = billsRes.data ?? [];
        if (modemRes != null && modemRes.success && modemRes.data != null) {
          _linkedModem = modemRes.data as Map<String, dynamic>?;
        }
      });
    }
  }

  Future<void> _confirmDeleteUser() async {
    final userId = widget.user['id']?.toString() ?? '';
    final userName = widget.user['name']?.toString() ?? 'User';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text('Are you sure you want to permanently delete "$userName"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              minimumSize: Size.zero,
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await AdminDataService.deleteUser(userId);
      if (res.success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted successfully')));
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: ${res.message}')));
      }
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF6366F1);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    final roleStr = _fullUser?['role'] ?? widget.user['role'];
    final roleLower = (roleStr?.toString() ?? '').toLowerCase();
    final isTech = roleLower.contains('tech');
    final isSales = roleLower.contains('sales');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user['name'] ?? 'User Profile'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _confirmDeleteUser,
            tooltip: 'Delete User',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(primaryColor, surfaceColor),
                if (!isTech && !isSales) ...[
                  TabBar(
                    controller: _tabController,
                    labelColor: primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: primaryColor,
                    tabs: const [
                      Tab(text: 'Details'),
                      Tab(text: 'Activity & Audit'),
                      Tab(text: 'Bills & Payments'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDetailsTab(),
                        _buildAuditTab(surfaceColor),
                        _buildBillsTab(surfaceColor, primaryColor),
                      ],
                    ),
                  ),
                ] else if (isTech) ...[
                  Expanded(
                    child: _buildTechnicianDetailsView(primaryColor, surfaceColor),
                  ),
                ] else ...[
                  Expanded(
                    child: _buildSalesDetailsView(primaryColor, surfaceColor),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildHeader(Color primaryColor, Color surfaceColor) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: primaryColor.withValues(alpha: 0.1),
            child: Icon(Icons.person, color: primaryColor, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.user['name'] ?? 'Unknown', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(widget.user['email'] ?? 'No email', style: const TextStyle(color: Colors.grey)),
                Text(widget.user['phone'] ?? 'No phone', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (widget.user['is_vip'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                        child: const Text('VIP', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    if (widget.user['is_vip'] == true) const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: widget.user['status'] == 'blocked' ? Colors.red : Colors.green, borderRadius: BorderRadius.circular(4)),
                      child: Text((widget.user['status'] ?? 'active').toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    final activePlan = _fullUser?['active_plan'] ?? widget.user['active_plan'] ?? 'No Plan';
    final hasPlan = activePlan != 'No Plan';
    
    // Progress calculation
    double progress = 0.0;
    String remainingDaysText = '';
    String planPeriodText = '';
    
    if (hasPlan && _fullUser?['plan_start_date'] != null && _fullUser?['plan_expiry_date'] != null) {
      try {
        final start = DateTime.parse(_fullUser!['plan_start_date']).toLocal();
        final expiry = DateTime.parse(_fullUser!['plan_expiry_date']).toLocal();
        final now = DateTime.now();
        
        final totalDuration = expiry.difference(start).inSeconds;
        final elapsed = now.difference(start).inSeconds;
        
        if (totalDuration > 0) {
          progress = (elapsed / totalDuration).clamp(0.0, 1.0);
        }
        
        final remaining = expiry.difference(now);
        if (remaining.isNegative) {
          remainingDaysText = 'Expired';
          progress = 1.0;
        } else {
          if (remaining.inDays > 0) {
            remainingDaysText = '${remaining.inDays} days remaining';
          } else if (remaining.inHours > 0) {
            remainingDaysText = '${remaining.inHours} hours remaining';
          } else {
            remainingDaysText = '${remaining.inMinutes} minutes remaining';
          }
        }
        
        final startF = _formatDateTime(_fullUser!['plan_start_date']).split(',')[0];
        final expiryF = _formatDateTime(_fullUser!['plan_expiry_date']).split(',')[0];
        planPeriodText = 'Cycle: $startF to $expiryF';
      } catch (_) {}
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          title: const Text('Role'),
          subtitle: Text((_fullUser?['role'] ?? widget.user['role'] ?? 'Customer').toString().toUpperCase()),
        ),
        ListTile(
          title: const Text('Active Plan'),
          subtitle: Text(activePlan),
        ),
        if (hasPlan && planPeriodText.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      planPeriodText,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      remainingDaysText,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: remainingDaysText == 'Expired' ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(
                      progress >= 0.9 ? Colors.red : (progress >= 0.7 ? Colors.amber : const Color(0xFF6366F1)),
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(progress * 100).toStringAsFixed(0)}% elapsed',
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
        ListTile(
          title: const Text('Created At'),
          subtitle: Text(_formatDateTime(_fullUser?['created_at']?.toString() ?? widget.user['created_at']?.toString())),
        ),
        const SizedBox(height: 24),
        if (_linkedModem != null) ...[
          const Text('Linked Modem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.router, color: Color(0xFF6366F1)),
                      const SizedBox(width: 8),
                      Text(_linkedModem!['device_type'] ?? 'Unknown Device', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Text('ONLINE', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const Divider(),
                  Text('MAC: ${_linkedModem!['mac_address']}'),
                  Text('IP: ${_linkedModem!['ip_address']}'),
                  Text('Signal: ${_linkedModem!['signal_strength']} dBm'),
                  Text('Last Synced: ${_linkedModem!['last_synced']}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        ElevatedButton.icon(
          onPressed: _showLinkModemDialog,
          icon: const Icon(Icons.router),
          label: Text(_linkedModem != null ? 'Update Modem' : 'Link Modem'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  void _showLinkModemDialog() {
    final macController = TextEditingController();
    final ipController = TextEditingController();
    String selectedType = 'Nokia ONT';
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              title: const Text('Link Hardware / Modem'),
              content: isSaving
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 16),
                      Center(child: CircularProgressIndicator()),
                      SizedBox(height: 24),
                      Text('Saving Device...', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 16),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: macController,
                        decoration: const InputDecoration(labelText: 'MAC Address', hintText: 'e.g., 00:1A:2B:3C:4D:5E'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: ipController,
                        decoration: const InputDecoration(labelText: 'IP Address (Optional)'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        items: ['Nokia ONT', 'Huawei Router', 'TP-Link Gateway', 'TP-Link Archer C6', 'FiberJet Core Edge']
                            .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                            .toList(),
                        onChanged: (val) => setDialogState(() => selectedType = val!),
                        decoration: const InputDecoration(labelText: 'Device Type'),
                      ),
                    ],
                  ),
              actions: [
                if (!isSaving)
                  TextButton(onPressed: () => Navigator.pop(builderContext), child: const Text('Cancel')),
                if (!isSaving)
                  ElevatedButton(
                  onPressed: () async {
                    if (macController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('MAC Address is required')));
                      return;
                    }
                    
                    setDialogState(() => isSaving = true);
                    
                    try {
                      final res = await AdminDataService.linkModem(widget.user['id'], {
                        'mac_address': macController.text.trim(),
                        'ip_address': ipController.text.trim(),
                        'device_type': selectedType,
                      });
                      
                      if (builderContext.mounted) {
                        Navigator.pop(builderContext); // close dialog only after success
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message.isNotEmpty ? res.message : (res.success ? 'Success' : 'Error'))));
                        if (res.success) {
                          _fetchUserData(); // Refresh the modem data to show the new card
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        setDialogState(() => isSaving = false); // restore dialog if error
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  child: const Text('Save Device'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildAuditTab(Color surfaceColor) {
    final complaintsList = _fullUser?['complaints'] as List? ?? [];
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Raised Tickets Section ──
        Row(
          children: [
            const Icon(Icons.confirmation_number, color: Color(0xFF6366F1), size: 20),
            const SizedBox(width: 8),
            Text('Raised Tickets (${complaintsList.length})', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        if (complaintsList.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Center(
              child: Text(
                'No support tickets raised yet.',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
              ),
            ),
          )
        else
          ...complaintsList.map((complaint) {
            final title = complaint['title'] ?? 'Complaint';
            final category = complaint['category'] ?? 'General';
            final compStatus = complaint['status'] ?? 'open';
            final description = complaint['description'] ?? '';
            final resolution = complaint['resolution'] ?? '';
            final assignedTo = complaint['assigned_to_name'] ?? 'Unassigned';
            final createdAt = _formatDateTime(complaint['created_at']);
            
            Color tc;
            switch (compStatus.toString().toLowerCase()) {
              case 'resolved':
                tc = Colors.green;
                break;
              case 'in_progress':
                tc = Colors.amber;
                break;
              default:
                tc = Colors.blue;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                border: Border.all(color: Colors.grey.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: tc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          compStatus.toString().toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: tc),
                        ),
                      ),
                      const Spacer(),
                      Text(createdAt, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('Category: $category | Handler: $assignedTo', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(description, style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                  ],
                  if (resolution.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Resolution: $resolution',
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.green, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),

        const SizedBox(height: 28),
        // ── System Audit Logs Section ──
        Row(
          children: [
            const Icon(Icons.history, color: Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text('System Audit Logs (${_auditLogs.length})', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        if (_auditLogs.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Center(
              child: Text(
                'No system audits logged.',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
              ),
            ),
          )
        else
          ..._auditLogs.map((log) {
            final action = log['action'] ?? 'Action';
            final target = log['target_table'] ?? 'system';
            final date = _formatDateTime(log['created_at']);

            return Card(
              color: surfaceColor,
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.settings_suggest_outlined),
                title: Text(action, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text('Target: $target \nLogged: $date', style: const TextStyle(fontSize: 11)),
                isThreeLine: true,
              ),
            );
          }),
      ],
    );
  }

  Widget _buildBillsTab(Color surfaceColor, Color primaryColor) {
    if (_bills.isEmpty) return const Center(child: Text('No billing history available.'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bills.length,
      itemBuilder: (context, index) {
        final bill = _bills[index];
        final planName = bill['plan_name'] ?? 'Plan Subscription';
        final amount = bill['amount'] ?? '0';
        final paidOn = _formatDateTime(bill['start_date']);
        final startDate = _formatDateTime(bill['start_date']).split(',')[0];
        final expiryDate = _formatDateTime(bill['expiry_date']).split(',')[0];

        return Card(
          color: surfaceColor,
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.green.withValues(alpha: 0.1),
                      child: const Icon(Icons.receipt_long, color: Colors.green),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            planName,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Paid on: $paidOn',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.picture_as_pdf, color: primaryColor),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading PDF Invoice...')));
                      },
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Plan Subscribed', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text('$startDate to $expiryDate', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Amount Paid', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text('\$$amount', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTechnicianDetailsView(Color primaryColor, Color surfaceColor) {
    final role = _fullUser?['role'] ?? widget.user['role'] ?? 'technician';
    final email = _fullUser?['email'] ?? widget.user['email'] ?? 'No email';
    final phone = _fullUser?['phone'] ?? widget.user['phone'] ?? 'No phone';
    final status = _fullUser?['status'] ?? widget.user['status'] ?? 'active';
    final createdAt = _fullUser?['created_at']?.toString() ?? '';
    final completedJobsCount = _fullUser?['completed_jobs'] ?? 0;
    final jobsList = _fullUser?['jobs'] as List? ?? [];
    final completedComplaintsCount = _fullUser?['resolved_complaints_count'] ?? 0;
    final complaintsList = _fullUser?['complaints'] as List? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Technician Stats Card ──
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Technician Information', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildDetailItem('Role', role.toString().toUpperCase(), Colors.orange),
              _buildDetailItem('Phone Number', phone, Colors.grey),
              _buildDetailItem('Email Address', email, Colors.grey),
              _buildDetailItem('Status', status.toString().toUpperCase(), status == 'active' ? Colors.green : Colors.red),
              _buildDetailItem('Created At', _formatDateTime(createdAt), Colors.grey),
              const Divider(height: 24),
              _buildDetailItem('Completed Jobs', '$completedJobsCount', Colors.blue),
              _buildDetailItem('Resolved Tickets', '$completedComplaintsCount', Colors.green),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Completed Jobs Section ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Completed Jobs ($completedJobsCount)', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        if (jobsList.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Center(
              child: Text(
                'No jobs completed yet.',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
              ),
            ),
          )
        else
          ...jobsList.map((job) {
            final type = job['type'] ?? 'Field Job';
            final jobStatus = job['status'] ?? 'pending';
            final customerName = job['customer_name'] ?? 'N/A';
            final completedAt = job['completed_at'] != null ? job['completed_at'].toString().split('T')[0] : 'N/A';
            final address = job['address'] ?? 'No address provided';
            Color sc = jobStatus == 'completed' ? Colors.green : Colors.blue;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                border: Border.all(color: Colors.grey.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: sc.withValues(alpha: 0.1),
                    child: Icon(Icons.handyman_rounded, color: sc, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              type.toString().toUpperCase(),
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                jobStatus.toString().toUpperCase(),
                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: sc),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Customer: $customerName', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                        Text('Address: $address', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (jobStatus == 'completed')
                          Text('Completed: $completedAt', style: GoogleFonts.inter(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 20),

        // ── Resolved Tickets (Complaints) Section ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Resolved Tickets ($completedComplaintsCount)', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        if (complaintsList.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Center(
              child: Text(
                'No tickets resolved yet.',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
              ),
            ),
          )
        else
          ...complaintsList.map((complaint) {
            final title = complaint['title'] ?? 'Complaint';
            final category = complaint['category'] ?? 'General';
            final compStatus = complaint['status'] ?? 'open';
            final customerName = complaint['customer_name'] ?? 'N/A';
            final resolution = complaint['resolution'] ?? '';
            final updatedAt = complaint['updated_at'] != null ? complaint['updated_at'].toString().split('T')[0] : 'N/A';

            Color tc;
            switch (compStatus.toString().toLowerCase()) {
              case 'resolved':
                tc = Colors.green;
                break;
              case 'in_progress':
                tc = Colors.amber;
                break;
              default:
                tc = Colors.red;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                border: Border.all(color: Colors.grey.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: tc.withValues(alpha: 0.1),
                    child: Icon(Icons.confirmation_number_rounded, color: tc, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: tc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                compStatus.toString().toUpperCase(),
                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: tc),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Category: $category', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                        Text('Customer: $customerName', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                        if (resolution.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text('Resolution: $resolution', style: GoogleFonts.inter(fontSize: 11, color: Colors.green, fontStyle: FontStyle.italic)),
                          ),
                        const SizedBox(height: 2),
                        Text('Resolved: $updatedAt', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildSalesDetailsView(Color primaryColor, Color surfaceColor) {
    final role = _fullUser?['role'] ?? widget.user['role'] ?? 'sales';
    final email = _fullUser?['email'] ?? widget.user['email'] ?? 'No email';
    final phone = _fullUser?['phone'] ?? widget.user['phone'] ?? 'No phone';
    final status = _fullUser?['status'] ?? widget.user['status'] ?? 'active';
    final createdAt = _fullUser?['created_at']?.toString() ?? '';
    final totalLeads = _fullUser?['total_leads'] ?? 0;
    final convertedLeads = _fullUser?['converted_leads'] ?? 0;
    final totalCommission = _fullUser?['total_commission'] ?? 0;
    final leadsList = _fullUser?['leads'] as List? ?? [];

    final conversionRate = totalLeads > 0 ? (convertedLeads / totalLeads * 100).toStringAsFixed(0) : '0';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Sales Stats Card ──
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sales Representative Info', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildDetailItem('Role', role.toString().toUpperCase(), Colors.purple),
              _buildDetailItem('Phone Number', phone, Colors.grey),
              _buildDetailItem('Email Address', email, Colors.grey),
              _buildDetailItem('Status', status.toString().toUpperCase(), status == 'active' ? Colors.green : Colors.red),
              _buildDetailItem('Created At', _formatDateTime(createdAt), Colors.grey),
              const Divider(height: 24),
              _buildDetailItem('Total Leads Assigned', '$totalLeads', Colors.blue),
              _buildDetailItem('Leads Converted', '$convertedLeads', Colors.green),
              _buildDetailItem('Conversion Rate', '$conversionRate%', Colors.amber),
              _buildDetailItem('Total Commission Earned', '\$$totalCommission', Colors.greenAccent),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Leads Section ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Leads Directory ($totalLeads)', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        if (leadsList.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Center(
              child: Text(
                'No leads generated yet.',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
              ),
            ),
          )
        else
          ...leadsList.map((lead) {
            final leadName = lead['customer_name'] ?? 'Unknown Customer';
            final leadPhone = lead['phone'] ?? 'No phone';
            final leadAddress = lead['address'] ?? 'No address provided';
            final leadStage = lead['stage'] ?? 'new';
            final leadDate = lead['created_at'] != null ? lead['created_at'].toString().split('T')[0] : 'N/A';

            Color stageColor;
            switch (leadStage.toString().toLowerCase()) {
              case 'installed':
                stageColor = Colors.green;
                break;
              case 'new':
                stageColor = Colors.blue;
                break;
              case 'contacted':
                stageColor = Colors.amber;
                break;
              default:
                stageColor = Colors.grey;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                border: Border.all(color: Colors.grey.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: stageColor.withValues(alpha: 0.1),
                    child: Icon(Icons.leaderboard_rounded, color: stageColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              leadName,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: stageColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                leadStage.toString().toUpperCase(),
                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: stageColor),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Phone: $leadPhone', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                        Text('Address: $leadAddress', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('Date: $leadDate', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey)),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }
}
