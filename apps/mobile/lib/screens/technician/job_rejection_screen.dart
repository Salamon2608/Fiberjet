import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fiberjet/services/tech_data_service.dart';

class JobRejectionScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> jobData;

  const JobRejectionScreen({super.key, required this.jobId, required this.jobData});

  @override
  State<JobRejectionScreen> createState() => _JobRejectionScreenState();
}

class _JobRejectionScreenState extends State<JobRejectionScreen> {
  static const Color _primary = Color(0xFFFDB612);

  String? _selectedReason;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  final _reasons = [
    'Customer Not Available',
    'Technical Feasibility Issue',
    'Equipment Failure',
    'Access Denied',
    'Safety Hazard',
    'Wrong Address',
    'Other',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRejection() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a reason'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please add a comment'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await TechDataService.rejectJob(
      jobId: widget.jobId,
      reason: _selectedReason!,
      comment: _commentController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Job rejected. Admin has been notified.'),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context, true); // Return true to refresh
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerName = widget.jobData['customer_name']?.toString() ?? 'Customer';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Row(children: [
          const SizedBox(width: 8),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: _primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.rocket_launch, color: _primary, size: 18),
          ),
        ]),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Job Rejection', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade900)),
          Text('#${widget.jobId.length > 6 ? widget.jobId.substring(0, 6).toUpperCase() : widget.jobId} • $customerName',
              style: GoogleFonts.spaceGrotesk(fontSize: 10, color: Colors.grey, letterSpacing: 1)),
        ]),
        actions: [IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Warning banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _primary.withOpacity(0.3)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.warning, color: Colors.black87, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('URGENT ACTION REQUIRED', style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text('Rejections require administrative review. Admin will be notified immediately.',
                    style: GoogleFonts.spaceGrotesk(fontSize: 13, color: Colors.grey.shade600)),
              ])),
            ]),
          ),
          const SizedBox(height: 24),
          _sectionLabel(Icons.list_alt, 'Select Reason for Rejection *'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedReason,
              decoration: const InputDecoration(border: InputBorder.none),
              hint: Text('Select the primary reason...', style: GoogleFonts.spaceGrotesk(color: Colors.grey)),
              style: GoogleFonts.spaceGrotesk(fontSize: 14, color: Colors.grey.shade900),
              items: _reasons.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => _selectedReason = val),
            ),
          ),
          const SizedBox(height: 24),
          _sectionLabel(Icons.edit_note, 'Detailed Comments *'),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            maxLines: 5,
            style: GoogleFonts.spaceGrotesk(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Provide details on why the job could not be completed...',
              hintStyle: GoogleFonts.spaceGrotesk(color: Colors.grey.shade400),
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _primary)),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitRejection,
              icon: _isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                  : const Text('Submit Rejection'),
              label: _isSubmitting ? const Text('Submitting...') : const Icon(Icons.send),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700),
                elevation: 6, shadowColor: Colors.red.withOpacity(0.3),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sectionLabel(IconData icon, String label) {
    return Row(children: [
      Icon(icon, size: 16, color: Colors.grey),
      const SizedBox(width: 6),
      Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 1)),
    ]);
  }
}
