import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchMap(double lat, double lng, String label) async {
    // Use OpenStreetMap URL
    final uri = Uri.parse('https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=16/$lat/$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFFF9B515);
    final surfaceColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Map Header — OpenStreetMap tile via static image
            GestureDetector(
              onTap: () => _launchMap(10.7905, 78.7047, 'FiberJet HQ'),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      'https://tile.openstreetmap.org/12/2950/1862.png',
                      fit: BoxFit.cover,
                      color: isDarkMode ? Colors.black.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.3),
                      colorBlendMode: isDarkMode ? BlendMode.darken : BlendMode.lighten,
                      errorBuilder: (_, _, _) => Container(
                        color: isDarkMode ? const Color(0xFF1E293B) : Colors.grey[200],
                        child: const Center(child: Icon(Icons.map, size: 64, color: Colors.grey)),
                      ),
                    ),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: primaryColor.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 4),
                          ],
                        ),
                        child: const Icon(Icons.location_on, color: Colors.black, size: 32),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.open_in_new, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('Open in Map', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Get in Touch', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 8),
                  Text(
                    'We are here to help you with any queries or support you need for your FiberJet connection.',
                    style: TextStyle(fontSize: 14, color: subtitleColor),
                  ),
                  const SizedBox(height: 32),

                  // Contact Actions Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.phone_in_talk,
                          title: 'Call Now',
                          subtitle: '24/7 Support',
                          color: primaryColor,
                          surfaceColor: surfaceColor,
                          textColor: textColor,
                          subtitleColor: subtitleColor,
                          onTap: () => _launchPhone('+918000123456'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.mail_outline,
                          title: 'Email Us',
                          subtitle: 'support@fiberjet.com',
                          color: Colors.blue,
                          surfaceColor: surfaceColor,
                          textColor: textColor,
                          subtitleColor: subtitleColor,
                          onTap: () => _launchEmail('support@fiberjet.com'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.chat_bubble_outline,
                          title: 'WhatsApp',
                          subtitle: 'Quick Chat',
                          color: const Color(0xFF25D366),
                          surfaceColor: surfaceColor,
                          textColor: textColor,
                          subtitleColor: subtitleColor,
                          onTap: () async {
                            final uri = Uri.parse('https://wa.me/918000123456?text=Hi%20FiberJet%20Support');
                            if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.language,
                          title: 'Website',
                          subtitle: 'fiberjet.com',
                          color: Colors.deepPurple,
                          surfaceColor: surfaceColor,
                          textColor: textColor,
                          subtitleColor: subtitleColor,
                          onTap: () async {
                            final uri = Uri.parse('https://fiberjet.com');
                            if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Offices Section
                  Text('Our Offices', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 16),

                  _buildOfficeItem(
                    title: 'Headquarters',
                    address: 'Expertisor Academy, Srirangam\nTiruchirappalli, Tamil Nadu 620006',
                    phone: '+91 80001 23456',
                    lat: 10.8617,
                    lng: 78.6833,
                    surfaceColor: surfaceColor,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(height: 16),
                  _buildOfficeItem(
                    title: 'Regional Office',
                    address: 'Woraiyur Main Road\nTiruchirappalli, Tamil Nadu 620003',
                    phone: '+91 80009 87654',
                    lat: 10.8233,
                    lng: 78.6800,
                    surfaceColor: surfaceColor,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                    primaryColor: primaryColor,
                  ),

                  const SizedBox(height: 32),

                  // Business hours
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.schedule, color: primaryColor, size: 20),
                            const SizedBox(width: 8),
                            Text('Business Hours', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildHoursRow('Mon - Fri', '9:00 AM - 9:00 PM', textColor, subtitleColor),
                        const SizedBox(height: 8),
                        _buildHoursRow('Saturday', '10:00 AM - 6:00 PM', textColor, subtitleColor),
                        const SizedBox(height: 8),
                        _buildHoursRow('Sunday', '10:00 AM - 2:00 PM', textColor, subtitleColor),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.headset_mic, size: 14, color: Colors.green),
                            const SizedBox(width: 4),
                            Text('Technical Support: 24/7', style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoursRow(String day, String hours, Color textColor, Color subtitleColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(day, style: TextStyle(color: subtitleColor, fontSize: 13)),
        Text(hours, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color surfaceColor,
    required Color textColor,
    required Color subtitleColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: subtitleColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficeItem({
    required String title,
    required String address,
    required String phone,
    required double lat,
    required double lng,
    required Color surfaceColor,
    required Color textColor,
    required Color subtitleColor,
    required Color primaryColor,
  }) {
    return InkWell(
      onTap: () => _launchMap(lat, lng, title),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.business, color: primaryColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: subtitleColor),
                      const SizedBox(width: 4),
                      Expanded(child: Text(address, style: TextStyle(fontSize: 13, color: subtitleColor, height: 1.4))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _launchPhone(phone.replaceAll(' ', '')),
                    child: Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 16, color: subtitleColor),
                        const SizedBox(width: 4),
                        Text(phone, style: TextStyle(fontSize: 13, color: primaryColor, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.map_outlined, size: 14, color: primaryColor),
                      const SizedBox(width: 4),
                      Text('Tap to open in map', style: TextStyle(fontSize: 11, color: primaryColor)),
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
}
