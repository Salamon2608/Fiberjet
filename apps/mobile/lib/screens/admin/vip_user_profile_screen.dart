import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VipUserProfileScreen extends StatelessWidget {
  final Map<String, dynamic> user;

  const VipUserProfileScreen({super.key, required this.user});

  static const Color _navy = Color(0xFF0A1128);
  static const Color _primary = Color(0xFFF9B515);
  static const Color _bgLight = Color(0xFFF8F7F5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              _buildTopBar(),
              _buildHeroCard(),
              const SizedBox(height: 16),
              _buildStatsRow(),
              const SizedBox(height: 24),
              _buildBenefitsSection(),
              const SizedBox(height: 24),
              _buildVerificationUpload(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.rocket_launch_rounded, color: _navy, size: 20),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_outlined, color: Colors.grey, size: 20),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _primary.withOpacity(0.2)),
            ),
            child: Icon(Icons.settings_outlined, color: _primary, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _navy,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Grid pattern
            Positioned.fill(
              child: CustomPaint(painter: _GridPatternPainter()),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                children: [
                  // Avatar with gold ring
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_primary, Colors.yellow.shade200, _primary],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withOpacity(0.3),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade700,
                            border: Border.all(color: _navy, width: 4),
                          ),
                          child: const Icon(Icons.person, color: Colors.white54, size: 48),
                        ),
                      ),
                      // Verified badge
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: _navy, width: 2),
                          ),
                          child: const Icon(Icons.verified, color: _navy, size: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(user['name'] ?? 'Unknown User',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.workspace_premium, color: _primary, size: 18),
                      const SizedBox(width: 6),
                      Text('GOLDEN BADGE MEMBER',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _primary,
                              letterSpacing: 2)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('MEMBER SINCE ${((user['created_at']?.toString() ?? '2023').split('-').first)}',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 10, color: Colors.white54, letterSpacing: 0.5)),
                  const SizedBox(height: 28),
                  // Tier Progress
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.75,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(_primary),
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('VIP LEVEL 4',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w500)),
                      Text('GOLDEN REWARDS ACTIVE',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 10,
                              color: _primary,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 110,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _statCard(
              icon: Icons.cloud_done_outlined,
              title: 'Extra Cloud Storage',
              value: '+50GB VIP Bonus',
              progress: 0.24,
              subtitle: '12.4GB of 50GB used',
              isDark: false,
            ),
            const SizedBox(width: 12),
            _statCard(
              icon: Icons.headset_mic_outlined,
              title: 'Support Status',
              value: 'Auto-Priority',
              subtitle: 'Dedicated agent online 24/7',
              isDark: true,
              showOnline: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
    double? progress,
    required String subtitle,
    required bool isDark,
    bool showOnline = false,
  }) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _navy : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? Border.all(color: _primary.withOpacity(0.2))
            : Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? _primary : _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: isDark ? _navy : _primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.grey)),
                    Text(value,
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.grey.shade900)),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          if (progress != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(_primary),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (showOnline)
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
          Text(subtitle,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 10, color: isDark ? Colors.white38 : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBenefitsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stars_rounded, color: _primary, size: 22),
              const SizedBox(width: 8),
              Text('Exclusive Benefits',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey.shade900)),
            ],
          ),
          const SizedBox(height: 14),
          _benefitTile(Icons.bolt_rounded, 'Hyper-Speed Routing',
              'Low-latency priority for gaming & calls.'),
          const SizedBox(height: 10),
          _benefitTile(Icons.workspace_premium_rounded, 'Golden Lounge Access',
              'Exclusive member-only webinars and perks.'),
        ],
      ),
    );
  }

  Widget _benefitTile(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900)),
                const SizedBox(height: 2),
                Text(desc,
                    style: GoogleFonts.spaceGrotesk(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildVerificationUpload() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _primary.withOpacity(0.3), width: 2),
          // Dashed border is not natively supported—use a solid subtle one
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_a_photo_rounded, color: _primary, size: 28),
            ),
            const SizedBox(height: 16),
            Text('Self-Service Verification',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 17, fontWeight: FontWeight.w700, color: _navy)),
            const SizedBox(height: 8),
            Text(
              'Upload device photos for instant\nremote diagnostics and support.',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: const Text('Upload Photos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: _navy,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                textStyle:
                    GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700),
                elevation: 4,
                shadowColor: _primary.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF9B515).withOpacity(0.08)
      ..style = PaintingStyle.fill;
    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x + 2, y + 2), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
