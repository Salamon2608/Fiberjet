import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fiberjet/services/tech_data_service.dart';
import 'package:fiberjet/screens/technician/job_chat_screen.dart';
import 'package:fiberjet/screens/technician/customer_rating_screen.dart';
import 'package:fiberjet/screens/technician/job_rejection_screen.dart';
import 'package:image_picker/image_picker.dart';

class ActiveJobScreen extends StatefulWidget {
  final String jobId;
  const ActiveJobScreen({super.key, required this.jobId});

  @override
  State<ActiveJobScreen> createState() => _ActiveJobScreenState();
}

class _ActiveJobScreenState extends State<ActiveJobScreen> {
  static const Color _primary = Color(0xFFF9B515);
  static const Color _navy = Color(0xFF0F172A);

  bool _isLoading = true;
  bool _isUpdating = false;
  Map<String, dynamic>? _job;
  List<dynamic> _photos = [];

  // Workflow steps in order
  static const _workflowSteps = ['pending', 'en_route', 'arrived', 'in_progress', 'completed'];

  @override
  void initState() {
    super.initState();
    _fetchJob();
  }

  Future<void> _fetchJob() async {
    setState(() => _isLoading = true);
    final result = await TechDataService.getJob(widget.jobId);
    if (result.success && result.data != null) {
      final data = result.data as Map<String, dynamic>;
      setState(() {
        _job = data;
        _photos = (data['photos'] as List?) ?? [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  int _currentStepIndex() {
    final status = _job?['status']?.toString() ?? 'pending';
    final idx = _workflowSteps.indexOf(status);
    return idx >= 0 ? idx : 0;
  }

  String _nextStatus() {
    final currentIdx = _currentStepIndex();
    if (currentIdx < _workflowSteps.length - 1) {
      return _workflowSteps[currentIdx + 1];
    }
    return 'completed';
  }

  String _nextStatusLabel() {
    switch (_nextStatus()) {
      case 'en_route': return 'Start Route';
      case 'arrived': return 'Mark Arrived';
      case 'in_progress': return 'Begin Work';
      case 'completed': return 'Complete Job';
      default: return 'Next Step';
    }
  }

  Future<void> _advanceStep() async {
    final next = _nextStatus();
    String? macAddress;
    String? arrivalOtp;

    if (next == 'arrived') {
      // Prompt for Customer In-App Arrival OTP
      final otpController = TextEditingController();
      final gotOtp = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.key, color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Customer Arrival OTP',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: _navy),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please ask the customer for the 4-digit arrival OTP displayed on their FiberJet app screen.',
                style: GoogleFonts.spaceGrotesk(fontSize: 13, color: Colors.grey[600], height: 1.4),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                autofocus: true,
                style: GoogleFonts.spaceGrotesk(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 8),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '• • • •',
                  hintStyle: const TextStyle(color: Colors.grey, letterSpacing: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _primary, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text('Cancel', style: GoogleFonts.spaceGrotesk(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final text = otpController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(ctx, text);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: _navy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Verify & Mark Arrived', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (gotOtp == null) {
        return; // User cancelled
      }
      arrivalOtp = gotOtp;
      setState(() => _isUpdating = true);
    } else if (next == 'completed') {
      // 1. Prompt for MAC Address
      final macController = TextEditingController();
      final formKey = GlobalKey<FormState>();
      
      final gotMac = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Link Modem', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: _navy)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Please enter the MAC address of the installed router/modem.',
                  style: GoogleFonts.spaceGrotesk(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: macController,
                  autofocus: true,
                  style: GoogleFonts.spaceGrotesk(),
                  decoration: InputDecoration(
                    hintText: 'AA:BB:CC:DD:EE:FF',
                    labelText: 'MAC Address',
                    labelStyle: GoogleFonts.spaceGrotesk(color: _navy),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _primary)),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'MAC Address is required';
                    }
                    final clean = val.trim();
                    final reg = RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$|^[0-9A-Fa-f]{12}$');
                    if (!reg.hasMatch(clean)) {
                      return 'Enter a valid MAC Address (e.g. AA:BB:CC:DD:EE:FF)';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text('Cancel', style: GoogleFonts.spaceGrotesk(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, macController.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: _navy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Next', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (gotMac == null) {
        return; // User cancelled
      }
      macAddress = gotMac;

      // 2. Prompt for completion photo
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Photo proof is mandatory to complete the job!'),
          backgroundColor: Colors.red,
        ));
        return;
      }
      
      setState(() => _isUpdating = true);
      // Upload the photo
      await TechDataService.uploadJobPhoto(
        jobId: widget.jobId,
        photoType: 'completion_proof',
        filePath: photo.path,
      );
    } else {
      setState(() => _isUpdating = true);
    }

    final result = await TechDataService.updateJobStatus(widget.jobId, next, macAddress: macAddress, otp: arrivalOtp);
    if (!mounted) return;

    setState(() => _isUpdating = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Status updated to ${next.replaceAll('_', ' ')}'),
        backgroundColor: Colors.green,
      ));
      _fetchJob();

      // If completed, show rating dialog
      if (next == 'completed') {
        final customerName = _job?['customer_name']?.toString() ?? 'Customer';
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => CustomerRatingScreen(
            jobId: widget.jobId,
            customerName: customerName,
          ),
        ));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: _navy, foregroundColor: Colors.white),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFFFBBF24))),
      );
    }

    if (_job == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: _navy, foregroundColor: Colors.white, title: const Text('Job Not Found')),
        body: const Center(child: Text('Could not load job details')),
      );
    }

    final status = _job!['status']?.toString() ?? 'pending';
    final isCompleted = status == 'completed';
    final isRejected = status == 'rejected';
    final customerName = _job!['customer_name']?.toString() ?? 'Customer';
    final jobId = widget.jobId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          'Job #${jobId.length > 6 ? jobId.substring(0, 6).toUpperCase() : jobId}',
          style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => JobChatScreen(jobId: jobId, customerName: customerName),
              ));
            },
            icon: Icon(Icons.chat_bubble_outline, color: _primary),
          ),
          if (!isCompleted && !isRejected)
            IconButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => JobRejectionScreen(jobId: jobId, jobData: _job!),
                )).then((_) => _fetchJob());
              },
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchJob,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(children: [
                  _buildClientInfo(),
                  _buildStepper(),
                  if (_photos.isNotEmpty) _buildPhotos(),
                ]),
              ),
            ),
          ),
        ],
      ),
      bottomSheet: (isCompleted || isRejected)
          ? Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Center(
                child: Text(
                  isCompleted ? '✅ Job Completed' : '❌ Job Rejected',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: isCompleted ? Colors.green : Colors.red,
                  ),
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : _advanceStep,
                  icon: _isUpdating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)))
                      : Text(_nextStatusLabel()),
                  label: _isUpdating ? const Text('Updating...') : const Icon(Icons.arrow_forward),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary, foregroundColor: _navy,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    textStyle: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700),
                    elevation: 6, shadowColor: _primary.withOpacity(0.3),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildClientInfo() {
    final customerName = _job!['customer_name']?.toString() ?? 'Customer';
    final address = _job!['address']?.toString() ?? 'N/A';
    final phone = _job!['customer_phone']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('CLIENT', style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 1.5)),
              Text(customerName, style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: _navy)),
              Text(address, style: GoogleFonts.spaceGrotesk(fontSize: 13, color: Colors.grey)),
              if (phone.isNotEmpty) Text(phone, style: GoogleFonts.spaceGrotesk(fontSize: 12, color: Colors.grey)),
            ]),
          ),
          CircleAvatar(radius: 22, backgroundColor: Colors.blue.shade50, child: Icon(Icons.person_pin, color: _navy, size: 22)),
        ]),
      ),
    );
  }

  Widget _buildStepper() {
    final currentIdx = _currentStepIndex();

    final steps = [
      {'icon': Icons.play_arrow, 'title': 'Job Started', 'subtitle': 'Accept and prepare', 'status': 'pending'},
      {'icon': Icons.directions_car, 'title': 'En Route', 'subtitle': 'Traveling to customer', 'status': 'en_route'},
      {'icon': Icons.check, 'title': 'Arrived', 'subtitle': 'Technician on-site', 'status': 'arrived'},
      {'icon': Icons.router, 'title': 'In Progress', 'subtitle': 'Installation / work underway', 'status': 'in_progress'},
      {'icon': Icons.verified, 'title': 'Completed', 'subtitle': 'Job finished successfully', 'status': 'completed'},
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Workflow Progress', style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700, color: _navy)),
        const SizedBox(height: 20),
        ...steps.asMap().entries.map((entry) {
          final i = entry.key;
          final step = entry.value;
          final isCompleted = i < currentIdx;
          final isActive = i == currentIdx;
          final hasLine = i < steps.length - 1;

          String statusText = '';
          if (isCompleted) statusText = 'Done';
          if (isActive) statusText = 'Current';

          return _stepItem(
            icon: step['icon'] as IconData,
            color: isCompleted ? Colors.green : (isActive ? _primary : Colors.grey),
            status: statusText,
            title: step['title'] as String,
            subtitle: step['subtitle'] as String,
            isCompleted: isCompleted,
            isActive: isActive,
            hasLine: hasLine,
          );
        }),
      ]),
    );
  }

  Widget _stepItem({
    required IconData icon, required Color color, required String status,
    required String title, required String subtitle,
    required bool isCompleted, required bool isActive, required bool hasLine,
  }) {
    final circleColor = isCompleted ? Colors.green : isActive ? _primary : Colors.white;
    final iconColor = isCompleted || isActive ? (isActive ? _navy : Colors.white) : Colors.grey.shade400;
    final textOpacity = isCompleted || isActive ? 1.0 : 0.5;

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
              border: isCompleted || isActive ? null : Border.all(color: Colors.grey.shade300, width: 2),
              boxShadow: isActive ? [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 12)] : null,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          if (hasLine) Expanded(child: Container(width: 2, color: isCompleted ? Colors.green.withOpacity(0.4) : Colors.grey.shade200)),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Opacity(
            opacity: textOpacity,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(title, style: GoogleFonts.spaceGrotesk(
                    fontSize: isActive ? 17 : 14,
                    fontWeight: FontWeight.w700,
                    color: isActive ? _navy : Colors.grey.shade800,
                  )),
                  if (status.isNotEmpty) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green.shade50 : _primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(status, style: GoogleFonts.spaceGrotesk(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: isCompleted ? Colors.green : _navy,
                    )),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.spaceGrotesk(fontSize: 13, color: Colors.grey)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildPhotos() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Photos (${_photos.length})', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _photos.map((p) {
            final photo = p as Map<String, dynamic>;
            return Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.image, color: Colors.grey, size: 28),
                Text(photo['photo_type']?.toString() ?? '', style: GoogleFonts.spaceGrotesk(fontSize: 8, color: Colors.grey)),
              ]),
            );
          }).toList(),
        ),
      ]),
    );
  }
}
