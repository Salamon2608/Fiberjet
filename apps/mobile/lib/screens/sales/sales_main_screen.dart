import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sales_dashboard_screen.dart';
import 'leads_pipeline_screen.dart';
import 'create_lead_screen.dart';
import 'sales_complaints_screen.dart';
import 'commission_tracker_screen.dart';
import 'sales_profile_screen.dart';

class SalesMainScreen extends StatefulWidget {
  const SalesMainScreen({super.key});

  @override
  State<SalesMainScreen> createState() => SalesMainScreenState();
}

class SalesMainScreenState extends State<SalesMainScreen> {
  int _currentIndex = 0;

  void selectTab(int index) {
    setState(() => _currentIndex = index);
  }

  static const Color _primary = Color(0xFFFBBF24);
  static const Color _navy = Color(0xFF1E3A8A);

  @override
  Widget build(BuildContext context) {
    final pages = [
      SalesDashboardScreen(onTabSelect: selectTab),
      const LeadsPipelineScreen(),
      const SizedBox(), // Placeholder for FAB
      const SalesComplaintsScreen(),
      const SalesProfileScreen(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateLeadScreen())),
        backgroundColor: _navy,
        shape: const CircleBorder(),
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          if (i == 2) return; // FAB placeholder
          setState(() => _currentIndex = i);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: _navy,
        unselectedItemColor: Colors.grey.shade400,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.view_kanban_rounded), label: 'Pipeline'),
          BottomNavigationBarItem(icon: SizedBox(width: 24, height: 24), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.support_agent_rounded), label: 'Tickets'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

