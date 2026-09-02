import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fiberjet/services/auth_provider.dart';
import 'package:fiberjet/services/admin_data_service.dart';
import 'package:fiberjet/screens/admin/admin_dashboard_screen.dart';
import 'package:fiberjet/screens/admin/ad_control_screen.dart';
import 'package:fiberjet/screens/admin/user_management_screen.dart';
import 'package:fiberjet/screens/admin/sales_management_screen.dart';
import 'package:fiberjet/screens/admin/technician_management_screen.dart';
import 'package:fiberjet/screens/admin/profit_expense_screen.dart';
import 'package:fiberjet/screens/admin/lead_oversight_screen.dart';
import 'package:fiberjet/screens/admin/plan_management_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _selectedIndex = 0;

  static const Color _bgDark = Color(0xFF0F172A);
  static const Color _primary = Color(0xFFF9B515);
  static const Color _navy = Color(0xFF1E3A8A);

  final List<Widget> _pages = [
    const AdminDashboardScreen(),
    const UserManagementScreen(),
    const AdControlScreen(),
    const ProfitExpenseScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      extendBody: true,
      floatingActionButton: SizedBox(
        width: 52,
        height: 52,
        child: FloatingActionButton(
          heroTag: null,
          onPressed: () => _showAdminMenu(context),
          backgroundColor: _navy,
          elevation: 6,
          shape: const CircleBorder(),
          child: const Icon(Icons.menu, color: Colors.white, size: 26),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: _bgDark,
        elevation: 0,
        notchMargin: 6,
        shape: const CircularNotchedRectangle(),
        height: 64,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.dashboard_outlined, Icons.dashboard, 'Overview', 0),
            _navItem(Icons.people_outline, Icons.people, 'Users', 1),
            const SizedBox(width: 48), // Space for FAB
            _navItem(Icons.ads_click_outlined, Icons.ads_click, 'Ads', 2),
            _navItem(Icons.account_balance_outlined, Icons.account_balance, 'Profits', 3),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, IconData activeIcon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? _primary : Colors.white38,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? _primary : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _bgDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 24),
              const Text('Admin Controls', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.people, color: _primary),
                title: const Text('All Users', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.support_agent, color: _primary),
                title: const Text('Sales Team', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesManagementScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.handyman, color: _primary),
                title: const Text('Technicians', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TechnicianManagementScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.leaderboard, color: _primary),
                title: const Text('Lead CRM', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LeadOversightScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance, color: _primary),
                title: const Text('Profit & Expenses', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfitExpenseScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.sim_card, color: _primary),
                title: const Text('Plan Management', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanManagementScreen()));
                },
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.person_outline, color: _primary),
                title: const Text('My Profile', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAdminProfileDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                  }
                },
              ),
            ],
          ),
        ),
      );
    },
    );
  }

  Future<void> _showAdminProfileDialog(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;

    final nameCtrl = TextEditingController(text: user['name']);
    final passCtrl = TextEditingController();
    bool obscurePass = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: _bgDark,
          title: const Text('My Profile', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.person_outline, color: _primary),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passCtrl,
                obscureText: obscurePass,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.lock_outline, color: _primary),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePass ? Icons.visibility : Icons.visibility_off, color: Colors.white38),
                    onPressed: () => setState(() => obscurePass = !obscurePass),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
              onPressed: () async {
                final data = <String, dynamic>{};
                if (nameCtrl.text.trim() != user['name']) data['name'] = nameCtrl.text.trim();
                if (passCtrl.text.isNotEmpty) data['password'] = passCtrl.text;

                if (data.isEmpty) {
                  Navigator.pop(ctx);
                  return;
                }

                Navigator.pop(ctx);
                final res = await AdminDataService.updateUser(user['id'], data);
                if (res.success) {
                  await authProvider.refreshProfile();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: ${res.message}')));
                  }
                }
              },
              child: const Text('Save', style: TextStyle(color: _navy, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
