import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fiberjet/services/sales_data_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fiberjet/screens/technician/tech_complaint_map_screen.dart';

class SalesComplaintsScreen extends StatefulWidget {
  const SalesComplaintsScreen({super.key});

  @override
  State<SalesComplaintsScreen> createState() => _SalesComplaintsScreenState();
}

class _SalesComplaintsScreenState extends State<SalesComplaintsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _tickets = [];
  bool _isLoading = true;
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final filters = ['', 'open', 'in_progress', 'resolved'];
        setState(() => _statusFilter = filters[_tabController.index]);
        _fetchTickets();
      }
    });
    _fetchTickets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchTickets() async {
    setState(() => _isLoading = true);
    final result = await SalesDataService.getComplaints(
      status: _statusFilter.isNotEmpty ? _statusFilter : null,
    );
    if (result.success && result.data != null) {
      setState(() {
        _tickets = result.data is List ? result.data : [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String complaintId, String newStatus, String? note) async {
    final result = await SalesDataService.updateComplaintStatus(
      complaintId: complaintId,
      status: newStatus,
      resolutionNote: note,
    );
    if (!mounted) return;
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ticket updated to ${newStatus.replaceAll('_', ' ')}'),
        backgroundColor: Colors.green,
      ));
      _fetchTickets();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _showStatusDialog(Map<String, dynamic> ticket) {
    final noteController = TextEditingController();
    final currentStatus = ticket['status']?.toString() ?? 'open';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

        return Container(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Update Ticket',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '#${ticket['id']?.toString().substring(0, 6).toUpperCase() ?? ''}',
                  style: GoogleFonts.inter(
                    color: subTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  ticket['title']?.toString() ?? 'Support Ticket',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Premium Customer Details Card with direct calling and live map coordinate options
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CUSTOMER DETAILS',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF475569),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  ticket['customer_name'] ?? 'N/A',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              // Call Action Button
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.green.withOpacity(0.15),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.phone, color: Colors.green, size: 18),
                                  onPressed: () async {
                                    final phone = ticket['customer_phone']?.toString() ?? '';
                                    if (phone.isNotEmpty) {
                                      final uri = Uri.parse('tel:${phone.replaceAll(' ', '')}');
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri);
                                      }
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Live Location/Map Pin Button
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: isDark
                                    ? const Color(0xFFFBBF24).withOpacity(0.15)
                                    : const Color(0xFF1E3A8A).withOpacity(0.1),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.map,
                                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF1E3A8A),
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx); // Close sheet
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TechComplaintMapScreen(ticket: ticket),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (ticket['customer_phone'] != null && ticket['customer_phone'].toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.phone_android, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                            const SizedBox(width: 8),
                            Text(
                              ticket['customer_phone'].toString(),
                              style: GoogleFonts.inter(
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ticket['customer_address'] ?? 'Expertisor Academy, Srirangam, Tiruchirappalli',
                              style: GoogleFonts.inter(
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Resolution Note',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  style: GoogleFonts.inter(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Add a note about the action taken...',
                    hintStyle: GoogleFonts.inter(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Set Status',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (currentStatus != 'in_progress')
                      Expanded(
                        child: _statusButton(
                          'In Progress',
                          Colors.orange,
                          Icons.engineering,
                          () {
                            Navigator.pop(ctx);
                            _updateStatus(ticket['id'].toString(), 'in_progress',
                                noteController.text.trim().isEmpty ? null : noteController.text.trim());
                          },
                        ),
                      ),
                    if (currentStatus != 'in_progress') const SizedBox(width: 8),
                    Expanded(
                      child: _statusButton(
                        'Resolved',
                        Colors.green,
                        Icons.check_circle,
                        () {
                          Navigator.pop(ctx);
                          _updateStatus(ticket['id'].toString(), 'resolved',
                              noteController.text.trim().isEmpty ? null : noteController.text.trim());
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statusButton(
                        'Rejected',
                        Colors.red,
                        Icons.cancel,
                        () {
                          Navigator.pop(ctx);
                          _updateStatus(ticket['id'].toString(), 'rejected',
                              noteController.text.trim().isEmpty ? null : noteController.text.trim());
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusButton(String label, Color color, IconData icon, VoidCallback onTap) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        scrolledUnderElevation: 0,
        title: Text('Billing Tickets', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFBBF24),
          labelColor: const Color(0xFFFBBF24),
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Open'),
            Tab(text: 'Active'),
            Tab(text: 'Done'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTickets,
        color: const Color(0xFFFBBF24),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
            : _tickets.isEmpty
                ? ListView(children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_rounded, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('No tickets found', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey)),
                            Text('Billing tickets will appear here', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400])),
                          ],
                        ),
                      ),
                    ),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tickets.length,
                    itemBuilder: (context, index) {
                      final t = _tickets[index] as Map<String, dynamic>;
                      return _buildTicketCard(t);
                    },
                  ),
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> t) {
    final status = t['status']?.toString() ?? 'open';
    Color statusColor;
    Color statusBg;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'resolved':
        statusColor = Colors.green;
        statusBg = Colors.green.withOpacity(0.1);
        statusLabel = 'Resolved';
        statusIcon = Icons.check_circle;
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        statusBg = Colors.orange.withOpacity(0.1);
        statusLabel = 'In Progress';
        statusIcon = Icons.engineering;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusBg = Colors.red.withOpacity(0.1);
        statusLabel = 'Rejected';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.blue;
        statusBg = Colors.blue.withOpacity(0.1);
        statusLabel = 'Open';
        statusIcon = Icons.fiber_new;
    }

    final createdAt = t['created_at']?.toString();
    String timeText = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) {
        final diff = DateTime.now().difference(dt);
        if (diff.inDays > 0) {
          timeText = '${diff.inDays}d ago';
        } else if (diff.inHours > 0) {
          timeText = '${diff.inHours}h ago';
        } else {
          timeText = '${diff.inMinutes}m ago';
        }
      }
    }

    return GestureDetector(
      onTap: () => _showStatusDialog(t),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.receipt_long, size: 16, color: Color(0xFF1E3A8A)),
                  const SizedBox(width: 6),
                  Text(t['category']?.toString() ?? 'Billing',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusLabel, style: GoogleFonts.inter(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(t['title']?.toString() ?? 'Support Ticket',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text(
              t['description']?.toString() ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.person, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(t['customer_name']?.toString() ?? 'Customer',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600])),
                ]),
                Row(children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(timeText, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500])),
                ]),
              ],
            ),
            if (t['resolution_note'] != null && t['resolution_note'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sticky_note_2, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(t['resolution_note'].toString(),
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
