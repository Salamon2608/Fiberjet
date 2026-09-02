import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fiberjet/services/admin_data_service.dart';
import 'package:fiberjet/services/api_service.dart';

class UserApprovalScreen extends StatefulWidget {
  const UserApprovalScreen({super.key});

  @override
  State<UserApprovalScreen> createState() => _UserApprovalScreenState();
}

class _UserApprovalScreenState extends State<UserApprovalScreen> {
  static const Color _bgDark = Color(0xFF0B1121);
  static const Color _surfaceDark = Color(0xFF151E32);
  static const Color _primary = Color(0xFF1152D4);
  static const Color _green = Color(0xFF10B981);
  static const Color _red = Color(0xFFEF4444);

  int _selectedFilter = 0;
  final _filters = ['All Requests', 'Technicians', 'Sales'];

  bool _isLoading = true;
  List<dynamic> _requests = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    String? role;
    if (_selectedFilter == 1) role = 'technician';
    if (_selectedFilter == 2) role = 'sales';

    final result = await AdminDataService.getUsers(
      kycStatus: 'pending',
      role: role,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success) {
          _requests = result.data['users'] ?? [];
        } else {
          _error = result.message;
        }
      });
    }
  }

  Future<void> _handleAction(String userId, String action, {String? reason}) async {
    final res = await AdminDataService.approveUser(userId, action, reason: reason);
    if (res.success) {
      _fetchRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User ${action}d successfully')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to $action: ${res.message}')),
        );
      }
    }
  }

  void _showResubmitDialog(String userId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceDark,
        title: Text('Ask for Resubmission', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: reasonController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Reason for resubmission (e.g. blurry photo)',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (reasonController.text.isNotEmpty) {
                _handleAction(userId, 'resubmit', reason: reasonController.text);
              }
            },
            child: Text('Submit', style: TextStyle(color: _primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: _primary))
                : _error != null 
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
                  : _requests.isEmpty
                    ? Center(child: Text('No pending requests', style: GoogleFonts.inter(color: Colors.white54)))
                    : RefreshIndicator(
                        onRefresh: _fetchRequests,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSearchBar(),
                              const SizedBox(height: 16),
                              _buildFilters(),
                              const SizedBox(height: 20),
                              _buildSectionTitle(),
                              const SizedBox(height: 12),
                              ..._requests.map((r) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _buildRequestCard(r),
                                  )),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User Approvals',
                    style: GoogleFonts.inter(
                        fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('Fiber Jet Admin Console',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white54)),
              ],
            ),
          ),
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _surfaceDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
              ),
              if (_requests.isNotEmpty)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: _red,
                      shape: BoxShape.circle,
                      border: Border.all(color: _surfaceDark, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search by name, ID, or role...',
          hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          suffixIcon: const Icon(Icons.tune, color: Colors.white38, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final selected = i == _selectedFilter;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedFilter = i);
              _fetchRequests();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? _primary : _surfaceDark,
                borderRadius: BorderRadius.circular(10),
                border: selected ? null : Border.all(color: Colors.white.withOpacity(0.05)),
                boxShadow: selected
                    ? [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 12)]
                    : null,
              ),
              alignment: Alignment.center,
              child: Row(
                children: [
                  if (i == 0) ...[
                    const Icon(Icons.group, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                  ] else if (i == 1) ...[
                    Icon(Icons.engineering, color: selected ? Colors.white : Colors.white54, size: 16),
                    const SizedBox(width: 6),
                  ] else ...[
                    Icon(Icons.point_of_sale, color: selected ? Colors.white : Colors.white54, size: 16),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    _filters[i],
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('PENDING VERIFICATION',
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white38,
                letterSpacing: 1.2)),
        Text('View History',
            style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w500, color: _primary)),
      ],
    );
  }

  Widget _buildRequestCard(dynamic req) {
    final String name = req['name'] ?? 'Unknown';
    final String role = req['role'] ?? 'user';
    final String id = req['id']?.toString().substring(0, 8) ?? 'N/A';
    final String timestamp = req['created_at'] ?? 'Just now';

    Color roleColor = Colors.green;
    IconData roleIcon = Icons.person;

    if (role.toLowerCase().contains('tech')) {
      roleColor = Colors.blue;
      roleIcon = Icons.engineering_rounded;
    } else if (role.toLowerCase().contains('sales')) {
      roleColor = Colors.purple;
      roleIcon = Icons.point_of_sale_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey.shade700,
                    child: Text(
                      name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').join(),
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1623),
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(roleIcon, size: 10, color: roleColor),
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
                    Text(name,
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: roleColor.withOpacity(0.2)),
                          ),
                          child: Text(role.toUpperCase(),
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: roleColor.shade300)),
                        ),
                        const SizedBox(width: 6),
                        Text('• ID: #$id',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1623),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Text(timestamp.length > 10 ? timestamp.substring(0, 10) : timestamp,
                    style: GoogleFonts.inter(fontSize: 9, color: Colors.white38)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDocumentViewer(req),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleAction(req['id'].toString(), 'reject'),
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _red,
                    side: BorderSide(color: _red.withOpacity(0.3)),
                    backgroundColor: _red.withOpacity(0.05),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showResubmitDialog(req['id'].toString()),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Resubmit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: BorderSide(color: Colors.orange.withOpacity(0.3)),
                    backgroundColor: Colors.orange.withOpacity(0.05),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleAction(req['id'].toString(), 'approve'),
                  icon: const Icon(Icons.check, size: 14),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                    elevation: 4,
                    shadowColor: _green.withOpacity(0.3),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentViewer(dynamic req) {
    final kycDocs = req['kyc_doc_paths'] as Map<String, dynamic>? ?? {};
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1623),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_outlined, size: 13, color: Colors.white38),
                  const SizedBox(width: 6),
                  Text('KYC Documents',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (kycDocs.isEmpty)
            Center(child: Text('No documents uploaded', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kycDocs.entries.map((e) {
                return Tooltip(
                  message: e.key.toUpperCase(),
                  child: Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(6),
                      image: DecorationImage(
                        image: NetworkImage(ApiService.baseUrl + e.value.toString()),
                        fit: BoxFit.cover,
                        onError: (_, __) => const Icon(Icons.broken_image, color: Colors.white54),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

extension on Color {
  Color get shade300 {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor();
  }
}
