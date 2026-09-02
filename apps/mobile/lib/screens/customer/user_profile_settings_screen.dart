import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fiberjet/services/customer_data_service.dart';
import 'package:fiberjet/services/customer_provider.dart';
import 'package:fiberjet/screens/customer/contact_us_screen.dart';
import 'package:fiberjet/services/auth_provider.dart';

class UserProfileSettingsScreen extends StatefulWidget {
  const UserProfileSettingsScreen({super.key});

  @override
  State<UserProfileSettingsScreen> createState() => _UserProfileSettingsScreenState();
}

class _UserProfileSettingsScreenState extends State<UserProfileSettingsScreen> {
  bool _liveLocationSharing = true;
  bool _isLoading = true;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    final result = await CustomerDataService.getProfile();
    if (result.success && result.data != null) {
      setState(() {
        _profile = result.data as Map<String, dynamic>;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editField(String field, String label, String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    final newValue = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit $label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: field == 'address' ? 3 : 1,
          keyboardType: field == 'phone'
              ? TextInputType.phone
              : field == 'email'
                  ? TextInputType.emailAddress
                  : field == 'address'
                      ? TextInputType.streetAddress
                      : TextInputType.name,
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF2DF0D),
              foregroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newValue != null && newValue.isNotEmpty && newValue != currentValue) {
      final res = await CustomerDataService.updateProfile({field: newValue});
      if (!mounted) return;
      if (res.success) {
        setState(() => _profile?[field] = newValue);
        // Refresh dashboard data too
        context.read<CustomerProvider>().fetchDashboard();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$label updated successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res.message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentCtrl,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newCtrl,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (currentCtrl.text.isEmpty || newCtrl.text.isEmpty) return;
                if (newCtrl.text != confirmCtrl.text) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('New passwords do not match'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                if (newCtrl.text.length < 6) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Password must be at least 6 characters'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF2DF0D),
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final res = await CustomerDataService.changePassword(
        currentPassword: currentCtrl.text,
        newPassword: newCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.message),
        backgroundColor: res.success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFF2DF0D))),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchProfile,
        color: const Color(0xFFF2DF0D),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(isDarkMode),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Transform.translate(
                  offset: const Offset(0, -40),
                  child: Column(
                    children: [
                      _buildPersonalInfoCard(isDarkMode),
                      const SizedBox(height: 24),
                      _buildActionButtons(isDarkMode),
                      const SizedBox(height: 24),
                      _buildSafetySection(isDarkMode),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    final name = _profile?['name'] ?? 'User';
    final role = _profile?['role'] ?? 'customer';
    final planName = (_profile?['active_plan'] as Map?)?['name'];

    return Container(
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 80),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
              const Row(
                children: [
                  Icon(Icons.rocket_launch, color: Color(0xFFF2DF0D), size: 24),
                  SizedBox(width: 8),
                  Text('Fiber Jet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white70),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF2DF0D), width: 3),
              color: const Color(0xFF1E293B),
            ),
            child: Center(
              child: Text(
                _getInitials(name),
                style: const TextStyle(color: Color(0xFFF2DF0D), fontSize: 36, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(
            planName != null ? 'Fiber Jet • $planName' : 'Fiber Jet ${role[0].toUpperCase()}${role.substring(1)}',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Widget _buildPersonalInfoCard(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PERSONAL INFO', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 20),
          _buildInfoField('Full Name', _profile?['name'] ?? 'Not set', Icons.person, isDarkMode,
              onEdit: () => _editField('name', 'Full Name', _profile?['name'] ?? '')),
          const SizedBox(height: 20),
          _buildInfoField('Mobile Number', _profile?['phone'] ?? 'Not set', Icons.smartphone, isDarkMode,
              onEdit: () => _editField('phone', 'Mobile Number', _profile?['phone'] ?? '')),
          const SizedBox(height: 20),
          _buildInfoField('Email Address', _profile?['email'] ?? 'Not set', Icons.mail, isDarkMode,
              onEdit: () => _editField('email', 'Email Address', _profile?['email'] ?? '')),
          const SizedBox(height: 20),
          _buildInfoField('Installation Address', _profile?['address'] ?? 'Not set', Icons.location_on, isDarkMode,
              onEdit: () => _editField('address', 'Installation Address', _profile?['address'] ?? '')),
        ],
      ),
    );
  }

  Widget _buildInfoField(String label, String value, IconData icon, bool isDarkMode, {VoidCallback? onEdit}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.grey, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              GestureDetector(
                onTap: onEdit,
                child: const Icon(Icons.edit, color: Color(0xFFF2DF0D), size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isDarkMode) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => _editField('phone', 'Mobile Number', _profile?['phone'] ?? ''),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF2DF0D),
            foregroundColor: const Color(0xFF0F172A),
            minimumSize: const Size(double.infinity, 64),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            shadowColor: const Color(0xFFF2DF0D).withValues(alpha: 0.3),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.sim_card_download),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Fetch & Change Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Update service line instantly', style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black54)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _showChangePasswordDialog,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            foregroundColor: isDarkMode ? Colors.white : Colors.black87,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.lock_reset, color: Colors.grey, size: 22),
                  SizedBox(width: 12),
                  Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSafetySection(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield, color: Color(0xFFF2DF0D), size: 20),
                    SizedBox(width: 8),
                    Text('Safety & Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFF2DF0D).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Text('COMPULSORY', style: TextStyle(color: Color(0xFFD9C705), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Live Location Sharing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 4),
                          Text(
                            'Required for precise fiber line installation and real-time maintenance tracking.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _liveLocationSharing,
                      onChanged: (val) => setState(() => _liveLocationSharing = val),
                      activeThumbColor: const Color(0xFFF2DF0D),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactUsScreen()));
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                    foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.contact_support_outlined, color: Colors.grey, size: 22),
                          SizedBox(width: 12),
                          Text('Contact Us', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () async {
                    await context.read<AuthProvider>().logout();
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pushReplacementNamed('/login');
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                    foregroundColor: Colors.redAccent,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, size: 22),
                      SizedBox(width: 12),
                      Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
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
}
