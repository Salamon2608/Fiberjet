import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fiberjet/services/auth_provider.dart';
import 'tech_notifications_screen.dart';
import 'tech_activity_screen.dart';
import 'tech_earnings_screen.dart';

class TechProfileScreen extends StatelessWidget {
  const TechProfileScreen({super.key});
  static const Color _navy = Color(0xFF1E3A8A);
  static const Color _gold = Color(0xFFFBBF24);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final name = user?['name']?.toString() ?? 'Technician';
    final phone = user?['phone']?.toString() ?? '';
    final email = user?['email']?.toString() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 28),
              decoration: BoxDecoration(color: _navy, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
              child: Column(children: [
                CircleAvatar(radius: 36, backgroundColor: _gold,
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'T',
                    style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: _navy))),
                const SizedBox(height: 12),
                Text(name, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                if (phone.isNotEmpty) Text(phone, style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
                if (email.isNotEmpty) Text(email, style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(20)),
                  child: Text('Technician', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _navy)),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(children: [
              _menuItem(context, Icons.monetization_on, 'Earnings & Payouts', Colors.green, () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TechEarningsScreen()))),
              _menuItem(context, Icons.notifications, 'Notifications', Colors.orange, () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TechNotificationsScreen()))),
              _menuItem(context, Icons.history, 'Activity Log', Colors.blue, () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TechActivityScreen()))),
              const SizedBox(height: 8),
              _menuItem(context, Icons.dark_mode, 'Dark Mode', Colors.purple, () {}),
              _menuItem(context, Icons.info_outline, 'App Version', Colors.grey, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FiberJet v1.0.0')));
              }),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              )),
              const SizedBox(height: 32),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500))),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ]),
      ),
    );
  }
}
