import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fiberjet/services/sales_data_service.dart';
import 'package:image_picker/image_picker.dart';

class CreateLeadScreen extends StatefulWidget {
  const CreateLeadScreen({super.key});

  @override
  State<CreateLeadScreen> createState() => _CreateLeadScreenState();
}

class _CreateLeadScreenState extends State<CreateLeadScreen> {
  static const Color _primary = Color(0xFFFDB612);

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isSubmitting = false;
  XFile? _idProofFile;
  XFile? _addressProofFile;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    final picker = ImagePicker();
    final source = type == 'id' ? ImageSource.camera : ImageSource.gallery;

    final file = await picker.pickImage(source: source, imageQuality: 80);
    if (file != null && mounted) {
      setState(() {
        if (type == 'id') {
          _idProofFile = file;
        } else {
          _addressProofFile = file;
        }
      });
    }
  }

  Widget _sourceButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        CircleAvatar(radius: 28, backgroundColor: _primary.withValues(alpha: 0.1), child: Icon(icon, color: _primary, size: 28)),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Future<void> _submitLead() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and Phone are required'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Step 1: Create the lead
    final result = await SalesDataService.createLead(
      customerName: name,
      phone: phone,
      email: email.isNotEmpty ? email : null,
      address: address.isNotEmpty ? address : null,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.red),
      );
      return;
    }

    // Step 2: Upload documents if any were captured
    final leadData = result.data as Map<String, dynamic>?;
    final leadId = leadData?['id']?.toString();

    if (leadId != null && (_idProofFile != null || _addressProofFile != null)) {
      // Read bytes from XFile (works on both mobile and web)
      final idBytes = _idProofFile != null ? await _idProofFile!.readAsBytes() : null;
      final addrBytes = _addressProofFile != null ? await _addressProofFile!.readAsBytes() : null;

      final uploadResult = await SalesDataService.uploadLeadDocuments(
        leadId,
        idProofBytes: idBytes,
        idProofFilename: _idProofFile?.name,
        addressProofBytes: addrBytes,
        addressProofFilename: _addressProofFile?.name,
      );

      if (!mounted) return;

      if (uploadResult.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lead created & documents uploaded!'), backgroundColor: Colors.green),
        );
      } else {
        // Lead was created but docs failed — still navigate back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lead created but document upload failed: ${uploadResult.message}'), backgroundColor: Colors.orange),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lead created successfully!'), backgroundColor: Colors.green),
      );
    }

    setState(() => _isSubmitting = false);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('New Lead Intake', style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: const Color(0xFF1E3A8A))),
                const SizedBox(height: 4),
                Text('Register a new customer for Fiber Jet high-speed internet.', style: GoogleFonts.spaceGrotesk(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 24),
                _sectionHeader(Icons.person, 'Customer Identity'),
                const SizedBox(height: 12),
                _inputField('Full Name *', 'e.g. Jonathan Doe', _nameController),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _inputField('Phone Number *', '+91 9876543210', _phoneController, keyboardType: TextInputType.phone)),
                  const SizedBox(width: 12),
                  Expanded(child: _inputField('Email Address', 'name@domain.com', _emailController, keyboardType: TextInputType.emailAddress)),
                ]),
                const SizedBox(height: 28),
                _sectionHeader(Icons.location_on, 'Location Details'),
                const SizedBox(height: 12),
                _textAreaField('Service Address', 'Enter complete installation address...', _addressController),
                const SizedBox(height: 28),
                _sectionHeader(Icons.verified_user, 'Document Verification'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _uploadButton(
                    Icons.photo_camera,
                    _idProofFile != null ? 'ID Captured ✓' : 'Capture ID',
                    'Official Proof',
                    _idProofFile != null,
                    () => _pickImage('id'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _uploadButton(
                    Icons.file_upload,
                    _addressProofFile != null ? 'Proof Uploaded ✓' : 'Upload Proof',
                    'Address Proof',
                    _addressProofFile != null,
                    () => _pickImage('address'),
                  )),
                ]),
              ]),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9)),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitLead,
            icon: _isSubmitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)))
                : const Text('SUBMIT LEAD INTAKE'),
            label: _isSubmitting ? const Text('Submitting...') : const Icon(Icons.arrow_forward),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.grey.shade900,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700),
              elevation: 6,
              shadowColor: _primary.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(children: [
      Icon(icon, color: _primary, size: 22),
      const SizedBox(width: 8),
      Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1E3A8A))),
    ]);
  }

  Widget _inputField(String label, String hint, TextEditingController controller, {TextInputType? keyboardType}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 1)),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.spaceGrotesk(fontSize: 14, color: const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: hint, hintStyle: GoogleFonts.spaceGrotesk(color: Colors.grey.shade400),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primary)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    ]);
  }

  Widget _textAreaField(String label, String hint, TextEditingController controller) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 1)),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        maxLines: 3, style: GoogleFonts.spaceGrotesk(fontSize: 14, color: const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: hint, hintStyle: GoogleFonts.spaceGrotesk(color: Colors.grey.shade400),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primary)),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    ]);
  }

  Widget _uploadButton(IconData icon, String title, String subtitle, bool isDone, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDone ? _primary.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDone ? _primary : Colors.grey.shade300, style: BorderStyle.solid, width: 2),
        ),
        child: Column(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isDone ? _primary.withValues(alpha: 0.2) : Colors.grey.shade100,
            child: Icon(isDone ? Icons.check : icon, color: isDone ? _primary : Colors.grey.shade600, size: 24),
          ),
          const SizedBox(height: 10),
          Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: isDone ? _primary : null)),
          Text(subtitle, style: GoogleFonts.spaceGrotesk(fontSize: 9, color: Colors.grey)),
        ]),
      ),
    );
  }
}
