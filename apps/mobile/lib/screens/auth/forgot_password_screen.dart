import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fiberjet/services/customer_data_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Step 0 = phone entry, 1 = OTP entry, 2 = new password
  int _step = 0;
  bool _isLoading = false;

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // OTP timer
  int _secondsLeft = 300; // 5 min
  Timer? _timer;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _secondsLeft = 300;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 0) {
        timer.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String get _timerText {
    final min = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final sec = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      _showError('Please enter a valid phone number');
      return;
    }
    setState(() => _isLoading = true);
    final result = await CustomerDataService.forgotPassword(phone);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      setState(() => _step = 1);
      _startTimer();

      // Show debug code if returned (dev mode)
      final debugCode = (result.data as Map?)?['debug_reset_code'];
      if (debugCode != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Dev OTP: $debugCode'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 10),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } else {
      // Still move forward to prevent phone enumeration
      setState(() => _step = 1);
      _startTimer();
    }
  }

  Future<void> _verifyAndProceed() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      _showError('Please enter a 6-digit code');
      return;
    }
    if (_secondsLeft <= 0) {
      _showError('OTP has expired. Please request a new one.');
      return;
    }
    setState(() => _step = 2);
  }

  Future<void> _resetPassword() async {
    final newPass = _newPassController.text.trim();
    final confirmPass = _confirmPassController.text.trim();

    if (newPass.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }
    if (newPass != confirmPass) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);
    final result = await CustomerDataService.resetPassword(
      phone: _phoneController.text.trim(),
      code: _otpController.text.trim(),
      newPassword: newPass,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      _timer?.cancel();
      _showSuccessDialog();
    } else {
      _showError(result.message);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF9B515),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: const Color(0xFFF9B515).withValues(alpha: 0.3), blurRadius: 20)],
              ),
              child: const Icon(Icons.check, color: Color(0xFF0A2540), size: 48),
            ),
            const SizedBox(height: 24),
            const Text('Password Reset!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Your password has been changed successfully. You can now login with your new password.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // close dialog
                  Navigator.pop(context); // back to login
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF9B515),
                  foregroundColor: const Color(0xFF0A2540),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Back to Login', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDarkMode ? const Color(0xFFF9B515) : const Color(0xFF0A2540),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step > 0) {
              setState(() => _step--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _step == 0
                ? _buildPhoneStep(isDarkMode)
                : _step == 1
                    ? _buildOtpStep(isDarkMode)
                    : _buildNewPasswordStep(isDarkMode),
          ),
        ),
      ),
    );
  }

  // ── Step 0: Phone Entry ─────────────────────────────────────
  Widget _buildPhoneStep(bool isDarkMode) {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        _buildHeroIcon(Icons.vpn_key, isDarkMode),
        const SizedBox(height: 48),
        Text(
          'Forgot Password?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5,
            color: isDarkMode ? const Color(0xFFF9B515) : const Color(0xFF0A2540),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Enter your registered phone number and we\'ll send you a 6-digit reset code.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.grey[400] : Colors.grey[600], height: 1.5),
        ),
        const SizedBox(height: 48),
        const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildInput(_phoneController, 'e.g., 9876543210', Icons.phone, TextInputType.phone, isDarkMode),
        const SizedBox(height: 24),
        _buildPrimaryButton('Send Reset Code', _isLoading ? null : _sendOTP, _isLoading),
        const SizedBox(height: 48),
        _buildBackToLogin(isDarkMode),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Step 1: OTP Entry ───────────────────────────────────────
  Widget _buildOtpStep(bool isDarkMode) {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        _buildHeroIcon(Icons.lock_clock, isDarkMode),
        const SizedBox(height: 48),
        Text(
          'Enter Reset Code',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5,
            color: isDarkMode ? const Color(0xFFF9B515) : const Color(0xFF0A2540),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'A 6-digit code has been sent to ${_phoneController.text}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.grey[400] : Colors.grey[600], height: 1.5),
        ),
        const SizedBox(height: 24),
        // Timer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: _secondsLeft > 0
                ? const Color(0xFFF9B515).withValues(alpha: 0.1)
                : Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer, size: 18, color: _secondsLeft > 0 ? const Color(0xFFF9B515) : Colors.red),
              const SizedBox(width: 8),
              Text(
                _secondsLeft > 0 ? 'Code expires in $_timerText' : 'Code expired',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _secondsLeft > 0 ? const Color(0xFFF9B515) : Colors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text('6-Digit Code', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildInput(_otpController, '000000', Icons.pin, TextInputType.number, isDarkMode, maxLength: 6),
        const SizedBox(height: 24),
        _buildPrimaryButton('Verify Code', _verifyAndProceed, false),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _secondsLeft <= 0 ? _sendOTP : null,
          child: Text(
            'Resend Code',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _secondsLeft <= 0 ? const Color(0xFFF9B515) : Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Step 2: New Password ────────────────────────────────────
  Widget _buildNewPasswordStep(bool isDarkMode) {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        _buildHeroIcon(Icons.lock_reset, isDarkMode),
        const SizedBox(height: 48),
        Text(
          'Create New Password',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5,
            color: isDarkMode ? const Color(0xFFF9B515) : const Color(0xFF0A2540),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your new password must be at least 6 characters long.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.grey[400] : Colors.grey[600], height: 1.5),
        ),
        const SizedBox(height: 48),
        const Text('New Password', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildPasswordInput(_newPassController, 'Enter new password', _obscureNew, isDarkMode,
            (val) => setState(() => _obscureNew = val)),
        const SizedBox(height: 20),
        const Text('Confirm Password', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildPasswordInput(_confirmPassController, 'Confirm new password', _obscureConfirm, isDarkMode,
            (val) => setState(() => _obscureConfirm = val)),
        const SizedBox(height: 24),
        _buildPrimaryButton('Reset Password', _isLoading ? null : _resetPassword, _isLoading),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Reusable UI Components ──────────────────────────────────

  Widget _buildHeroIcon(IconData icon, bool isDarkMode) {
    return Center(
      child: SizedBox(
        width: 150, height: 150,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9B515).withValues(alpha: isDarkMode ? 0.05 : 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(child: Icon(icon, size: 72, color: const Color(0xFFF9B515))),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint, IconData icon,
      TextInputType type, bool isDarkMode, {int? maxLength}) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        border: Border.all(color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        maxLength: maxLength,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: isDarkMode ? Colors.grey[500] : Colors.grey[400]),
          hintText: hint,
          hintStyle: TextStyle(color: isDarkMode ? Colors.grey[600] : Colors.grey[400]),
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPasswordInput(TextEditingController controller, String hint, bool obscure,
      bool isDarkMode, ValueChanged<bool> onToggle) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        border: Border.all(color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.lock_outline, color: isDarkMode ? Colors.grey[500] : Colors.grey[400]),
          hintText: hint,
          hintStyle: TextStyle(color: isDarkMode ? Colors.grey[600] : Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20, color: Colors.grey),
            onPressed: () => onToggle(!obscure),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback? onPressed, bool isLoading) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF9B515),
        foregroundColor: const Color(0xFF0A2540),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        shadowColor: const Color(0xFFF9B515).withValues(alpha: 0.3),
      ),
      child: isLoading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A2540)))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 20),
              ],
            ),
    );
  }

  Widget _buildBackToLogin(bool isDarkMode) {
    return TextButton.icon(
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.arrow_back_ios, size: 14),
      label: const Text('Back to Login'),
      style: TextButton.styleFrom(
        foregroundColor: isDarkMode ? const Color(0xFFF9B515) : const Color(0xFF0A2540),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
