import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fiberjet/services/auth_provider.dart';
import 'package:fiberjet/services/sales_data_service.dart';
import 'package:fiberjet/services/customer_data_service.dart';

class SalesProfileScreen extends StatefulWidget {
  const SalesProfileScreen({super.key});

  @override
  State<SalesProfileScreen> createState() => _SalesProfileScreenState();
}

class _SalesProfileScreenState extends State<SalesProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  Map<String, dynamic> _dashboardData = {};
  String? _error;

  bool _isEditingProfile = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Fetch profile and dashboard data in parallel
    final results = await Future.wait([
      CustomerDataService.getProfile(),
      SalesDataService.getDashboard(),
    ]);

    setState(() {
      _isLoading = false;
      if (results[0].success) {
        _profile = results[0].data;
        if (!_isEditingProfile) {
          _nameController.text = _profile?['name']?.toString() ?? '';
          _phoneController.text = _profile?['phone']?.toString() ?? '';
          _emailController.text = _profile?['email']?.toString() ?? '';
        }
      } else {
        _error = results[0].message;
      }
      if (results[1].success && results[1].data != null) {
        _dashboardData = results[1].data as Map<String, dynamic>;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _toggleEditProfile() async {
    if (_isEditingProfile) {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();

      if (name.isEmpty || phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name and Phone cannot be empty.'), backgroundColor: Colors.red),
        );
        return;
      }

      setState(() => _isLoading = true);
      final result = await CustomerDataService.updateProfile({
        'name': name,
        'phone': phone,
        'email': email,
      });

      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully.'), backgroundColor: Colors.green),
          );
          setState(() {
            _isEditingProfile = false;
          });
          _fetchData();
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update profile: ${result.message}'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      setState(() {
        _isEditingProfile = true;
      });
    }
  }



  Widget _buildHeader(Color navyColor, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
      decoration: BoxDecoration(
        color: navyColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: navyColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.person_rounded, color: navyColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Profile',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Sales Representative',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.blue.shade200,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_profile != null) ...[
                Row(
                  children: [
                    if (_isEditingProfile)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isEditingProfile = false;
                            _nameController.text = _profile?['name']?.toString() ?? '';
                            _phoneController.text = _profile?['phone']?.toString() ?? '';
                            _emailController.text = _profile?['email']?.toString() ?? '';
                          });
                        },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _toggleEditProfile,
                      icon: Icon(_isEditingProfile ? Icons.save : Icons.edit, color: primaryColor, size: 18),
                      label: Text(
                        _isEditingProfile ? 'Save' : 'Edit',
                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const surfaceColor = Colors.white;
    const textColor = Color(0xFF0F172A);
    const primaryColor = Color(0xFFFBBF24); // Redesigned Brand Color: Amber/Orange
    const navyColor = Color(0xFF1E3A8A); // Redesigned Brand Color: Navy
    const bgLightColor = Color(0xFFF3F4F6); // Matching background

    return Scaffold(
      backgroundColor: bgLightColor,
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryColor))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _fetchData, child: const Text('Retry')),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    color: primaryColor,
                    child: Column(
                      children: [
                        _buildHeader(navyColor, primaryColor),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Profile Header
                        Center(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: primaryColor.withValues(alpha: 0.1),
                                child: const Icon(Icons.person, size: 50, color: primaryColor),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _profile?['name'] ?? _dashboardData['name'] ?? 'No Name',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                              ),
                              const SizedBox(height: 4),
                              if (_profile?['email'] != null)
                                Text(
                                  _profile!['email'].toString(),
                                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                                ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Sales Representative',
                                  style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Performance Stats — from dashboard API
                        const Text('Performance Stats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildStatCard(
                              'Total\nLeads',
                              _dashboardData['total_leads']?.toString() ?? '0',
                              Icons.trending_up, Colors.blue, surfaceColor,
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: _buildStatCard(
                              'Leader\nRank',
                              _dashboardData['leaderboard_rank'] != null && _dashboardData['leaderboard_rank'] != 0
                                  ? '#${_dashboardData['leaderboard_rank']}'
                                  : '--',
                              Icons.emoji_events, Colors.purple, surfaceColor,
                            )),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Contact Info
                        const Text('Contact Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                          ),
                          child: _isEditingProfile
                              ? Column(
                                  children: [
                                    TextField(
                                      controller: _nameController,
                                      style: TextStyle(color: textColor),
                                      decoration: InputDecoration(
                                        labelText: 'Full Name',
                                        labelStyle: TextStyle(color: Colors.grey.shade500),
                                        prefixIcon: const Icon(Icons.person_outline, color: primaryColor),
                                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller: _phoneController,
                                      style: TextStyle(color: textColor),
                                      decoration: InputDecoration(
                                        labelText: 'Phone Number',
                                        labelStyle: TextStyle(color: Colors.grey.shade500),
                                        prefixIcon: const Icon(Icons.phone_outlined, color: primaryColor),
                                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                                      ),
                                      keyboardType: TextInputType.phone,
                                    ),
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller: _emailController,
                                      style: TextStyle(color: textColor),
                                      decoration: InputDecoration(
                                        labelText: 'Email Address',
                                        labelStyle: TextStyle(color: Colors.grey.shade500),
                                        prefixIcon: const Icon(Icons.email_outlined, color: primaryColor),
                                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInfoRow('Name', _profile?['name']?.toString() ?? 'N/A'),
                                    const Divider(height: 24),
                                    _buildInfoRow('Phone', _profile?['phone']?.toString() ?? 'N/A'),
                                    const Divider(height: 24),
                                    _buildInfoRow('Email', _profile?['email']?.toString() ?? 'N/A'),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 32),



                        // Logout
                        GestureDetector(
                          onTap: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text('Logout', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                                content: Text('Are you sure you want to logout?', style: GoogleFonts.inter()),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text('Logout', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true && context.mounted) {
                              await context.read<AuthProvider>().logout();
                              if (context.mounted) {
                                Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.red.shade100),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    'Logout',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.red),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
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


  Widget _buildStatCard(String title, String value, IconData icon, Color color, Color surfaceColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
    );
  }
}
