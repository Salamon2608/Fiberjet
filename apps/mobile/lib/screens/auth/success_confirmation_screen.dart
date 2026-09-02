import 'dart:math';
import 'package:flutter/material.dart';

class SuccessConfirmationScreen extends StatefulWidget {
  final String title;
  final String message;
  final String? referenceId;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SuccessConfirmationScreen({
    super.key,
    this.title = 'Great Success!',
    this.message = 'Your request is being processed. We\'re launching your new experience at supersonic speeds.',
    this.referenceId,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<SuccessConfirmationScreen> createState() => _SuccessConfirmationScreenState();
}

class _SuccessConfirmationScreenState extends State<SuccessConfirmationScreen>
    with TickerProviderStateMixin {
  late AnimationController _rocketController;
  late AnimationController _confettiController;
  late AnimationController _fadeController;

  late Animation<double> _rocketScale;
  late Animation<double> _rocketBounce;
  late Animation<double> _fadeIn;
  late Animation<double> _glowPulse;

  final List<_ConfettiParticle> _confettiParticles = [];

  @override
  void initState() {
    super.initState();

    // Rocket animation
    _rocketController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _rocketScale = CurvedAnimation(parent: _rocketController, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut));
    _rocketBounce = CurvedAnimation(parent: _rocketController, curve: const Interval(0.4, 1.0, curve: Curves.bounceOut));

    // Confetti animation
    _confettiController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    _generateConfetti();

    // Fade in content
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);

    // Glow pulse
    _glowPulse = Tween<double>(begin: 0.2, end: 0.5).animate(
      CurvedAnimation(parent: _rocketController, curve: Curves.easeInOut),
    );

    // Start animations in sequence
    _rocketController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      _confettiController.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      _fadeController.forward();
    });
  }

  void _generateConfetti() {
    final rng = Random();
    for (int i = 0; i < 30; i++) {
      _confettiParticles.add(_ConfettiParticle(
        x: rng.nextDouble(),
        y: rng.nextDouble() * 0.3,
        size: 4 + rng.nextDouble() * 8,
        color: [
          const Color(0xFFF9B515),
          const Color(0xFFFF6B6B),
          const Color(0xFF4ECDC4),
          const Color(0xFF45B7D1),
          const Color(0xFFFF9FF3),
          Colors.white,
        ][rng.nextInt(6)],
        speed: 0.3 + rng.nextDouble() * 0.7,
        rotation: rng.nextDouble() * 3.14,
      ));
    }
  }

  @override
  void dispose() {
    _rocketController.dispose();
    _confettiController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF231D0F) : const Color(0xFFF8F7F5),
      body: SafeArea(
        child: Stack(
          children: [
            // Confetti layer
            AnimatedBuilder(
              animation: _confettiController,
              builder: (context, _) => CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _ConfettiPainter(_confettiParticles, _confettiController.value),
              ),
            ),
            // Content
            Center(
              child: Container(
                margin: const EdgeInsets.all(16),
                constraints: const BoxConstraints(maxWidth: 480),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1C1917) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF9B515).withValues(alpha: 0.1)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 24, offset: Offset(0, 12)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top bar
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9B515),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.speed, size: 16, color: Color(0xFF0A2540)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'FIBER JET',
                                style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : const Color(0xFF0A2540),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Success Content
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          // Animated rocket
                          AnimatedBuilder(
                            animation: _rocketController,
                            builder: (context, _) => Stack(
                              alignment: Alignment.center,
                              children: [
                                // Glow
                                Container(
                                  width: 150, height: 150,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFF9B515).withValues(alpha: _glowPulse.value),
                                        blurRadius: 50,
                                        spreadRadius: 20,
                                      ),
                                    ],
                                  ),
                                ),
                                // Rocket circle
                                Transform.scale(
                                  scale: _rocketScale.value,
                                  child: Transform.translate(
                                    offset: Offset(0, -10 * _rocketBounce.value + 10),
                                    child: Container(
                                      width: 96, height: 96,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9B515),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFF9B515).withValues(alpha: 0.3),
                                            blurRadius: 20,
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.rocket_launch, color: Color(0xFF0A2540), size: 48),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Fade-in text
                          FadeTransition(
                            opacity: _fadeIn,
                            child: Column(
                              children: [
                                Text(
                                  widget.title,
                                  style: TextStyle(
                                    fontSize: 32, fontWeight: FontWeight.bold,
                                    color: isDarkMode ? Colors.white : const Color(0xFF0A2540),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  widget.message,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.grey[400] : Colors.grey[600], height: 1.5),
                                ),
                                const SizedBox(height: 32),

                                // Status Info Card
                                if (widget.referenceId != null)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8F7F5),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'REQUEST STATUS',
                                              style: TextStyle(
                                                fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5,
                                                color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF9B515).withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                'PROCESSING',
                                                style: TextStyle(color: Color(0xFFF9B515), fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0, end: 0.65),
                                          duration: const Duration(milliseconds: 1500),
                                          curve: Curves.easeOut,
                                          builder: (context, value, _) => ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: value,
                                              backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF9B515)),
                                              minHeight: 6,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.info_outline, size: 14, color: isDarkMode ? Colors.grey[500] : Colors.grey[400]),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Reference ID: ${widget.referenceId}',
                                              style: TextStyle(fontSize: 10, color: isDarkMode ? Colors.grey[500] : Colors.grey[400]),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                const SizedBox(height: 24),

                                // Actions
                                ElevatedButton(
                                  onPressed: widget.onAction ?? () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF9B515),
                                    foregroundColor: const Color(0xFF0A2540),
                                    minimumSize: const Size(double.infinity, 50),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(widget.actionLabel ?? 'Go to Home', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward, size: 16),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom accent strip
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFF9B515).withValues(alpha: 0.1),
                            const Color(0xFFF9B515),
                            const Color(0xFFF9B515).withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Confetti Particle Model ───────────────────────────────────
class _ConfettiParticle {
  final double x;
  final double y;
  final double size;
  final Color color;
  final double speed;
  final double rotation;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.speed,
    required this.rotation,
  });
}

// ── Confetti Painter ──────────────────────────────────────────
class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()..color = p.color.withValues(alpha: (1 - progress).clamp(0, 1));
      final x = p.x * size.width;
      final y = (p.y + progress * p.speed) * size.height;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + progress * 6.28);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), const Radius.circular(2)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}
