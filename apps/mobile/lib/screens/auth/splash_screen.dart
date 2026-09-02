import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fiberjet/services/auth_provider.dart';
import 'package:fiberjet/services/storage_service.dart';
import 'package:fiberjet/services/customer_data_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _progressController.forward().then((_) => _checkAuthAndNavigate());
  }

  Future<void> _checkAuthAndNavigate() async {
    if (!mounted) return;

    // Try to restore session from stored token
    final auth = context.read<AuthProvider>();
    // auth.init() is called in main.dart

    if (!mounted) return;

    if (auth.isLoggedIn) {
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
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A2540),
      body: Stack(
        children: [
          // Background Tech Grid Pattern
          Positioned.fill(
             child: Opacity(
               opacity: 0.05,
               child: CustomPaint(painter: GridPainter()),
             ),
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Spacer(),
                
                // Main Content Area
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      // Logo Container
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A2540),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFF9B515).withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF9B515).withValues(alpha: 0.15),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.rocket_launch_outlined,
                            color: Color(0xFFF9B515),
                            size: 64,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Brand Name
                      const Text(
                        'FIBER JET',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'HYPER-SPEED INTERNET',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                          letterSpacing: 3.0,
                        ),
                      ),
                      
                      const SizedBox(height: 48),
                      
                      // Progress Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Initializing connection...',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              AnimatedBuilder(
                                animation: _progressAnimation,
                                builder: (context, child) {
                                  final percentage = (_progressAnimation.value * 100).toInt();
                                  return Text(
                                    '$percentage%',
                                    style: const TextStyle(
                                      color: Color(0xFFF9B515),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          AnimatedBuilder(
                            animation: _progressAnimation,
                            builder: (context, child) {
                              return LinearProgressIndicator(
                                value: _progressAnimation.value,
                                backgroundColor: Colors.white.withValues(alpha: 0.1),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFF9B515),
                                ),
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'SERVER: US-EAST-1',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontFamily: 'monospace',
                                ),
                              ),
                              Text(
                                'PING: 12ms',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Footer
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    children: [
                      Text(
                        'Powered by Fiber Jet',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFooterBadge('Fast'),
                          _buildDot(),
                          _buildFooterBadge('Secure'),
                          _buildDot(),
                          _buildFooterBadge('Reliable'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterBadge(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: Colors.white.withValues(alpha: 0.4),
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildDot() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: Color(0xFFF9B515),
        shape: BoxShape.circle,
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = const Color(0xFFF9B515)
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
