import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fiberjet/services/auth_provider.dart';
import 'package:fiberjet/services/api_service.dart';
import 'package:fiberjet/screens/auth/forgot_password_screen.dart';
import 'package:fiberjet/services/storage_service.dart';
import 'package:fiberjet/services/customer_data_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedCountryCode = '+91';
  bool _isEmailMode = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    String? error;

    if (_isEmailMode) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (email.isEmpty || password.isEmpty) {
        _showError('Please fill in all fields');
        setState(() => _isLoading = false);
        return;
      }

      error = await auth.loginWithEmail(email, password);
    } else {
      final phone = '$_selectedCountryCode${_phoneController.text.trim()}';

      if (_phoneController.text.trim().isEmpty) {
        _showError('Please enter your phone number');
        setState(() => _isLoading = false);
        return;
      }

      // For OTP flow, first request OTP
      final result = await ApiService.post('/auth/otp/generate', body: {
        'phone': phone,
      });

      if (result.success) {
        _showError('OTP sent! Check your phone.');
        // In a full implementation, show OTP input dialog here
      } else {
        error = result.message;
      }
    }

    setState(() => _isLoading = false);

    if (error != null) {
      _showError(error);
    } else if (auth.isLoggedIn) {
      if (!mounted) return;
      final role = auth.userRole;
      if (role == 'customer') {
        final userId = auth.currentUser?['id']?.toString();
        bool onboarded = await StorageService.isOnboardingComplete(userId);
        if (!onboarded) {
          try {
            final dashResult = await CustomerDataService.getDashboardData();
            if (dashResult.success && dashResult.data != null) {
              final data = dashResult.data as Map<String, dynamic>;
              if (data['active_plan'] != null) {
                await StorageService.setOnboardingComplete(userId);
                onboarded = true;
              }
            }
          } catch (_) {}
        }
        if (!mounted) return;
        if (onboarded) {
          Navigator.of(context).pushNamedAndRemoveUntil('/customer', (route) => false);
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (route) => false);
        }
      } else if (role == 'admin' || role == 'sales' || role == 'technician') {
        Navigator.of(context).pushNamedAndRemoveUntil('/$role', (route) => false);
      } else {
        _showError('Unauthorized role: $role');
        await auth.logout();
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {},
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF9B515),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.bolt,
                color: Color(0xFF0A2540),
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Fiber Jet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Grid Pattern
          Positioned.fill(
            child: Opacity(
              opacity: isDarkMode ? 0.05 : 0.03,
              child: CustomPaint(
                  painter: GridPainter(
                      color: isDarkMode ? Colors.white : Colors.black)),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  // Welcome Message
                  const Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A2540),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your hyper-speed connection.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Login Input Form
                  if (!_isEmailMode) ...[
                    Text(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.grey[300]
                            : const Color(0xFF0A2540),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Country Code Picker
                        Container(
                          height: 56,
                          width: 100,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.white,
                            border: Border.all(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey[300]!,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCountryCode,
                              icon: const Icon(Icons.arrow_drop_down),
                              isExpanded: true,
                              dropdownColor: isDarkMode
                                  ? const Color(0xFF0A2540)
                                  : Colors.white,
                                items: const [
                                DropdownMenuItem(value: '+1', child: Text('+1 🇺🇸')),
                                DropdownMenuItem(value: '+44', child: Text('+44 🇬🇧')),
                                DropdownMenuItem(value: '+91', child: Text('+91 🇮🇳')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedCountryCode = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Phone Number Input
                        Expanded(
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.white,
                              border: Border.all(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey[300]!,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hintText: '000-000-0000',
                                hintStyle: TextStyle(
                                  color: isDarkMode
                                      ? Colors.grey[600]
                                      : Colors.grey[400],
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                                suffixIcon: Icon(
                                  Icons.smartphone,
                                  color: isDarkMode
                                      ? Colors.grey[500]
                                      : Colors.grey[400],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Email Address Field
                    Text(
                      'Email Address',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.grey[300]
                            : const Color(0xFF0A2540),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.white,
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey[300]!,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'name@example.com',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Password Field
                    Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.grey[300]
                            : const Color(0xFF0A2540),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.white,
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey[300]!,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                          );
                        },
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Main Action Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_isEmailMode ? 'Login' : 'Send OTP'),
                              const SizedBox(width: 8),
                              Icon(_isEmailMode ? Icons.login : Icons.send, size: 20),
                            ],
                          ),
                  ),

                  const SizedBox(height: 16),
                  // Toggle Button
                  TextButton(
                    onPressed: () =>
                        setState(() => _isEmailMode = !_isEmailMode),
                    child: Text(_isEmailMode
                        ? 'Use Phone Number instead'
                        : 'Use Email instead'),
                  ),

                  const SizedBox(height: 32),
                  // Divider
                  Row(
                    children: [
                      Expanded(
                          child: Divider(
                              color: isDarkMode
                                  ? Colors.grey[800]
                                  : Colors.grey[300])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Or continue with',
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.grey[500]
                                : Colors.grey[500],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                          child: Divider(
                              color: isDarkMode
                                  ? Colors.grey[800]
                                  : Colors.grey[300])),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Google Login Button
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white,
                      foregroundColor: isDarkMode
                          ? Colors.white
                          : const Color(0xFF0A2540),
                      elevation: 0,
                      side: BorderSide(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.g_mobiledata, size: 32, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Continue with Google',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),
                  // Footer
                  Text(
                    'By continuing, you agree to our Terms of Service and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    double step = 40;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
