import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:fiberjet/services/tech_data_service.dart';
import 'tech_dashboard_screen.dart';
import 'tech_complaints_screen.dart';
import 'tech_customers_screen.dart';
import 'tech_profile_screen.dart';
import 'tech_earnings_screen.dart';
import 'tech_notifications_screen.dart';
import 'tech_activity_screen.dart';
import 'tech_job_history_screen.dart';
import 'tech_pool_screen.dart';

class TechMainScreen extends StatefulWidget {
  const TechMainScreen({super.key});
  @override
  State<TechMainScreen> createState() => _TechMainScreenState();
}

class _TechMainScreenState extends State<TechMainScreen> {
  int _currentIndex = 0;
  static const Color _secondary = Color(0xFF1E3A8A);

  int _poolCount = 0;
  Timer? _poolTimer;

  final _pages = <Widget>[
    const TechDashboardScreen(),
    const TechPoolScreen(), // Real-time claimable job pool
    const SizedBox(), // FAB placeholder
    const TechComplaintsScreen(), // Technician's assigned complaints
    const TechProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _fetchPoolCount();
    // Poll the pool size every 15 seconds to keep the badge updated in real-time
    _poolTimer = Timer.periodic(const Duration(seconds: 15), (_) => _fetchPoolCount());
  }

  @override
  void dispose() {
    _poolTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPoolCount() async {
    try {
      final res = await TechDataService.getJobPool();
      if (res.success && res.data != null) {
        final data = res.data as Map<String, dynamic>;
        final pool = (data['pool'] as List?) ?? [];
        if (mounted) {
          setState(() {
            _poolCount = pool.length;
          });
        }
      }
    } catch (_) {}
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Quick Actions', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _secondary)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 20,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _actionBtn(Icons.monetization_on, 'Earnings', Colors.green, () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TechEarningsScreen()));
                }),
                _actionBtn(Icons.notifications, 'Alerts', Colors.orange, () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TechNotificationsScreen()));
                }),
                _actionBtn(Icons.history, 'Job History', Colors.blue, () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TechJobHistoryScreen()));
                }),
                _actionBtn(Icons.timeline, 'Activity', Colors.purple, () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TechActivityScreen()));
                }),
                _actionBtn(Icons.people_rounded, 'Customers', Colors.indigo, () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TechCustomersScreen()));
                }),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      floatingActionButton: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [_secondary, Colors.blue.shade800]),
          border: Border.all(color: const Color(0xFFF3F4F6), width: 4),
          boxShadow: [BoxShadow(color: _secondary.withValues(alpha: 0.3), blurRadius: 10)],
        ),
        child: FloatingActionButton(
          heroTag: null,
          onPressed: _showQuickActions,
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(Icons.apps, color: Colors.white, size: 26),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          if (i == 2) return;
          setState(() {
            _currentIndex = i;
            if (i == 1) {
              _fetchPoolCount(); // Trigger immediate update on navigating to pool tab
            }
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: _secondary,
        unselectedItemColor: Colors.grey.shade400,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 10),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
          BottomNavigationBarItem(
            icon: _poolCount > 0
                ? Badge(
                    label: Text('$_poolCount', style: const TextStyle(fontSize: 9, color: Colors.white)),
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.workspaces_rounded),
                  )
                : const Icon(Icons.workspaces_rounded),
            label: 'Pool',
          ),
          const BottomNavigationBarItem(icon: SizedBox(width: 24, height: 24), label: ''),
          const BottomNavigationBarItem(icon: Icon(Icons.support_agent_rounded), label: 'My Tickets'),
          const BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
