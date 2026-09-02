import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fiberjet/services/sales_data_service.dart';
import 'package:fiberjet/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class LeadCommentsScreen extends StatefulWidget {
  final String leadId;
  final String leadName;

  const LeadCommentsScreen({
    super.key,
    required this.leadId,
    required this.leadName,
  });

  @override
  State<LeadCommentsScreen> createState() => _LeadCommentsScreenState();
}

class _LeadCommentsScreenState extends State<LeadCommentsScreen> {
  static const Color _primary = Color(0xFFFBBF24);
  static const Color _navy = Color(0xFF1E3A8A);
  static const Color _bgLight = Color(0xFFF3F4F6);
  static const Color _card = Colors.white;

  bool _isLoading = true;
  Map<String, dynamic>? _leadDetail;
  Map<String, dynamic> _documents = {};
  String? _errorMessage;

  static const _stages = [
    'new',
    'contacted',
    'kyc_uploaded',
    'approved',
    'installed',
  ];

  static const _stageLabels = {
    'new': 'New',
    'contacted': 'Contacted',
    'kyc_uploaded': 'KYC Uploaded',
    'approved': 'Approved',
    'installed': 'Installed',
  };

  static final _stageColors = {
    'new': const Color(0xFF3B82F6),
    'contacted': const Color(0xFFF59E0B),
    'kyc_uploaded': const Color(0xFF8B5CF6),
    'approved': const Color(0xFF10B981),
    'installed': const Color(0xFF6B7280),
  };

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final results = await Future.wait([
      SalesDataService.getLead(widget.leadId),
      SalesDataService.getLeadDocuments(widget.leadId),
    ]);
    if (mounted) {
      setState(() {
        _isLoading = false;
        final leadResult = results[0];
        final docResult = results[1];
        if (leadResult.success && leadResult.data != null) {
          _leadDetail = leadResult.data as Map<String, dynamic>;
        } else {
          _errorMessage = leadResult.message.isNotEmpty ? leadResult.message : 'Failed to load lead details';
        }
        if (docResult.success && docResult.data != null) {
          final data = docResult.data as Map<String, dynamic>;
          _documents = (data['documents'] as Map<String, dynamic>?) ?? {};
        }
      });
    }
  }

  Future<void> _changeStage(String newStage) async {
    if (newStage == 'approved') {
      await _showTechnicianPicker();
      return;
    }

    setState(() => _isLoading = true);
    final result = await SalesDataService.updateLead(widget.leadId, {'stage': newStage});
    if (mounted) {
      if (result.success) {
        _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lead stage updated successfully'), backgroundColor: Colors.green),
        );
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showTechnicianPicker() async {
    setState(() => _isLoading = true);
    final res = await SalesDataService.getTechnicians();
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message), backgroundColor: Colors.red));
      return;
    }

    final techs = (res.data['technicians'] as List?) ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assign Technician', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: _navy)),
              const SizedBox(height: 8),
              Text('Select a technician to assign this new installation.', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 20),
              if (techs.isEmpty)
                Center(child: Text('No technicians found', style: GoogleFonts.inter(color: Colors.grey)))
              else
                SizedBox(
                  height: 250,
                  child: ListView.builder(
                    itemCount: techs.length,
                    itemBuilder: (context, index) {
                      final t = techs[index];
                      final isOnline = t['is_online'] == true;
                      final tName = t['name']?.toString() ?? '';
                      final displayName = tName.trim().isEmpty ? 'Technician' : tName;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: isOnline ? Colors.green.shade100 : Colors.grey.shade200,
                          child: Icon(Icons.engineering, color: isOnline ? Colors.green : Colors.grey),
                        ),
                        title: Text(displayName, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black87)),
                        subtitle: Text(isOnline ? 'Online • Available' : 'Offline', style: GoogleFonts.inter(color: isOnline ? Colors.green : Colors.grey, fontSize: 12)),
                        onTap: () {
                          Navigator.pop(ctx);
                          _approveWithTechnician(t['id'].toString());
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approveWithTechnician(String techId) async {
    setState(() => _isLoading = true);
    final result = await SalesDataService.updateLead(widget.leadId, {
      'stage': 'approved',
      'technician_id': techId,
    });
    if (mounted) {
      if (result.success) {
        _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lead approved and assigned successfully!'), backgroundColor: Colors.green),
        );
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final leadIdShort = widget.leadId.length > 6
        ? widget.leadId.substring(0, 6).toUpperCase()
        : widget.leadId.toUpperCase();

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text('Lead Details', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
            Text('#FJ-$leadIdShort', style: GoogleFonts.inter(fontSize: 11, color: Colors.blue.shade200)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _errorMessage != null && _leadDetail == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load details',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: _fetchData,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: _navy,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Retry',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  color: _primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_leadDetail != null) ...[
                          _buildProfileCard(),
                          const SizedBox(height: 20),
                          _buildDocumentsSection(),
                          const SizedBox(height: 20),
                          _buildStageTimeline(),
                          const SizedBox(height: 20),
                          _buildActionsSection(),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildProfileCard() {
    final lead = _leadDetail!;
    final name = lead['customer_name']?.toString() ?? widget.leadName;
    final phone = lead['phone']?.toString() ?? '';
    final email = lead['email']?.toString() ?? '';
    final address = lead['address']?.toString() ?? '';
    final stage = lead['stage']?.toString() ?? 'new';
    final stageColor = _stageColors[stage] ?? Colors.grey;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
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
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: stageColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Customer Profile',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              // Edit button
              GestureDetector(
                onTap: () => _editLead(lead),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.edit_rounded, size: 18, color: _navy),
                ),
              ),
              const SizedBox(width: 8),
              // Delete button
              GestureDetector(
                onTap: _deleteLead,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          _profileRow(Icons.phone_rounded, 'Phone', phone),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 12),
            _profileRow(Icons.email_rounded, 'Email', email),
          ],
          if (address.isNotEmpty) ...[
            const SizedBox(height: 12),
            _profileRow(Icons.location_on_rounded, 'Address', address),
          ],
        ],
      ),
    );
  }

  void _editLead(Map<String, dynamic> lead) {
    final nameCtrl = TextEditingController(text: lead['customer_name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: lead['phone']?.toString() ?? '');
    final emailCtrl = TextEditingController(text: lead['email']?.toString() ?? '');
    final addressCtrl = TextEditingController(text: lead['address']?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _navy.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.edit_rounded, size: 20, color: _navy),
                    ),
                    const SizedBox(width: 12),
                    Text('Edit Customer Details', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: _navy)),
                  ],
                ),
                const SizedBox(height: 20),
                _editField('Customer Name', nameCtrl, Icons.person_rounded),
                const SizedBox(height: 12),
                _editField('Phone', phoneCtrl, Icons.phone_rounded),
                const SizedBox(height: 12),
                _editField('Email', emailCtrl, Icons.email_rounded),
                const SizedBox(height: 12),
                _editField('Address', addressCtrl, Icons.location_on_rounded),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text('Cancel', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(ctx);
                          setState(() => _isLoading = true);
                          final updates = <String, dynamic>{};
                          if (nameCtrl.text.trim().isNotEmpty) updates['customer_name'] = nameCtrl.text.trim();
                          if (phoneCtrl.text.trim().isNotEmpty) updates['phone'] = phoneCtrl.text.trim();
                          updates['email'] = emailCtrl.text.trim();
                          if (addressCtrl.text.trim().isNotEmpty) updates['address'] = addressCtrl.text.trim();

                          final result = await SalesDataService.updateLead(widget.leadId, updates);
                          if (mounted) {
                            if (result.success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Customer details updated!'), backgroundColor: Colors.green),
                              );
                              _fetchData();
                            } else {
                              setState(() => _isLoading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Update failed: ${result.message}'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _navy,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text('Save', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white))),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _editField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500),
        prefixIcon: Icon(icon, size: 18, color: _navy.withValues(alpha: 0.5)),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _navy, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Future<void> _deleteLead() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_rounded, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Delete Lead', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        content: Text(
          'This will permanently delete this lead and all associated data. This action cannot be undone.',
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    final result = await SalesDataService.deleteLead(widget.leadId);

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lead deleted successfully'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true); // Go back and refresh the list
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: ${result.message}'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _profileRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _navy.withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildDocumentsSection() {
    final idProof = _documents['id_proof']?.toString();
    final addressProof = _documents['address_proof']?.toString();
    final hasAny = (idProof != null && idProof.isNotEmpty) ||
        (addressProof != null && addressProof.isNotEmpty);

    // Build the full image URL from the relative path
    String imageUrl(String path) {
      // path is like "/uploads/kyc/123/id_proof.jpg"
      // baseUrl is "http://127.0.0.1:8080"
      return '${ApiService.baseUrl}$path';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
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
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.folder_special_rounded, size: 18, color: Color(0xFF8B5CF6)),
              ),
              const SizedBox(width: 10),
              Text(
                'KYC Documents',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
              children: [
                // ID Proof slot
                Expanded(
                  child: (idProof != null && idProof.isNotEmpty)
                      ? _docCard('ID Proof', Icons.badge_rounded, imageUrl(idProof), const Color(0xFF3B82F6), docType: 'id_proof')
                      : _uploadPlaceholder('ID Proof', Icons.badge_rounded, const Color(0xFF3B82F6), 'id_proof'),
                ),
                const SizedBox(width: 12),
                // Address Proof slot
                Expanded(
                  child: (addressProof != null && addressProof.isNotEmpty)
                      ? _docCard('Address Proof', Icons.home_rounded, imageUrl(addressProof), const Color(0xFF10B981), docType: 'address_proof')
                      : _uploadPlaceholder('Address Proof', Icons.home_rounded, const Color(0xFF10B981), 'address_proof'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _docCard(String label, IconData icon, String imageUrl, Color color, {required String docType}) {
    return GestureDetector(
      onTap: () => _showDocOptions(label, icon, imageUrl, color, docType),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: color.withValues(alpha: 0.1),
                    child: Icon(icon, size: 36, color: color),
                  ),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Center(child: CircularProgressIndicator(strokeWidth: 2, color: color));
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploadPlaceholder(String label, IconData icon, Color color, String docType) {
    return GestureDetector(
      onTap: () => _reuploadDoc(docType),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.cloud_upload_rounded, size: 24, color: color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to upload',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: color.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDocOptions(String label, IconData icon, String imageUrl, Color color, String docType) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: _navy),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _optionTile(
              Icons.visibility_rounded,
              'View Document',
              'Open in browser',
              const Color(0xFF3B82F6),
              () async {
                Navigator.pop(ctx);
                final uri = Uri.parse(imageUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open document in browser')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 8),
            _optionTile(
              Icons.edit_rounded,
              'Replace Document',
              'Re-upload a new file',
              const Color(0xFFF59E0B),
              () {
                Navigator.pop(ctx);
                _reuploadDoc(docType);
              },
            ),
            const SizedBox(height: 8),
            _optionTile(
              Icons.delete_rounded,
              'Delete Document',
              'Remove this document',
              Colors.red,
              () {
                Navigator.pop(ctx);
                _deleteDoc(docType, label);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _reuploadDoc(String docType) async {
    final picker = ImagePicker();
    final source = docType == 'id_proof' ? ImageSource.camera : ImageSource.gallery;

    final file = await picker.pickImage(source: source, imageQuality: 80);
    if (file == null || !mounted) return;

    setState(() => _isLoading = true);

    final bytes = await file.readAsBytes();
    final result = await SalesDataService.uploadLeadDocuments(
      widget.leadId,
      idProofBytes: docType == 'id_proof' ? bytes : null,
      idProofFilename: docType == 'id_proof' ? file.name : null,
      addressProofBytes: docType == 'address_proof' ? bytes : null,
      addressProofFilename: docType == 'address_proof' ? file.name : null,
    );

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document replaced successfully!'), backgroundColor: Colors.green),
      );
      _fetchData(); // Refresh to show new image
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: ${result.message}'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _reuploadSourceBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        CircleAvatar(radius: 28, backgroundColor: _primary.withValues(alpha: 0.1), child: Icon(icon, color: _primary, size: 28)),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Future<void> _deleteDoc(String docType, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete $label?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('This will permanently remove this document.', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    // Clear the document path by updating lead with empty path for this doc type
    final result = await SalesDataService.updateLead(widget.leadId, {
      'kyc_doc_path': _buildUpdatedDocPath(docType),
    });

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label deleted'), backgroundColor: Colors.green),
      );
      _fetchData();
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: ${result.message}'), backgroundColor: Colors.red),
      );
    }
  }

  /// Build the updated doc path JSON string with the specified doc removed.
  String _buildUpdatedDocPath(String docTypeToRemove) {
    final idProof = docTypeToRemove == 'id_proof' ? '' : (_documents['id_proof']?.toString() ?? '');
    final addressProof = docTypeToRemove == 'address_proof' ? '' : (_documents['address_proof']?.toString() ?? '');
    return '{"id_proof":"$idProof","address_proof":"$addressProof"}';
  }

  void _showFullImage(String title, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _navy),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: InteractiveViewer(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(40),
                      child: Icon(Icons.broken_image_rounded, size: 64, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageTimeline() {
    final lead = _leadDetail!;
    final currentStage = lead['stage']?.toString() ?? 'new';
    final currentIndex = _stages.indexOf(currentStage);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pipeline Status Tracker',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(_stages.length, (i) {
            final stage = _stages[i];
            final label = _stageLabels[stage] ?? stage;
            final isCompleted = i < currentIndex;
            final isCurrent = i == currentIndex;
            final color = _stageColors[stage] ?? Colors.grey;
            final isLast = i == _stages.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? color
                              : isCurrent
                                  ? Colors.white
                                  : Colors.grey.shade200,
                          border: Border.all(
                            color: isCompleted || isCurrent ? color : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : isCurrent
                                  ? Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: color,
                                      ),
                                    )
                                  : null,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 36,
                          color: isCompleted ? color : Colors.grey.shade200,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                            color: isCurrent
                                ? Colors.grey.shade800
                                : isCompleted
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade400,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Current Stage',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    final lead = _leadDetail!;
    final stage = lead['stage']?.toString() ?? 'new';
    final stageLabel = stage.replaceAll('_', ' ');
    final stageColor = _stageColors[stage] ?? Colors.grey;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lead Management',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Change Stage',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: _changeStage,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: stageColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: stageColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: stageColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        stageLabel[0].toUpperCase() + stageLabel.substring(1),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: stageColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down_rounded, size: 20, color: stageColor),
                    ],
                  ),
                ),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'new', child: Text('New')),
                  PopupMenuItem(value: 'contacted', child: Text('Contacted')),
                  PopupMenuItem(value: 'kyc_uploaded', child: Text('KYC Uploaded')),
                  PopupMenuItem(value: 'approved', child: Text('Approved')),
                ],
              ),
            ],
          ),
          if (stage == 'approved' || stage == 'installed') ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.engineering_rounded, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assigned Technician',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lead['technician_name']?.toString() ?? 'Pending Assignment',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _showTechnicianPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _navy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_rounded, size: 14, color: _navy),
                        const SizedBox(width: 6),
                        Text(
                          'Re-assign',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
