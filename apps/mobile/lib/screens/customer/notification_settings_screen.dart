import 'package:flutter/material.dart';
import 'package:fiberjet/services/customer_data_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  bool networkAlerts = true;
  bool securityWarnings = true;
  bool billReminders = true;
  bool promotionalOffers = false;

  // Profile data for delivery channels
  String _email = '';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    // Fetch preferences and profile in parallel
    final results = await Future.wait([
      CustomerDataService.getNotificationPreferences(),
      CustomerDataService.getProfile(),
    ]);

    final prefsResult = results[0];
    final profileResult = results[1];

    if (prefsResult.success && prefsResult.data != null) {
      final prefs = prefsResult.data as Map<String, dynamic>;
      networkAlerts = prefs['network_alerts'] ?? true;
      securityWarnings = prefs['security_warnings'] ?? true;
      billReminders = prefs['bill_reminders'] ?? true;
      promotionalOffers = prefs['promotional_offers'] ?? false;
    }

    if (profileResult.success && profileResult.data != null) {
      final profile = profileResult.data as Map<String, dynamic>;
      _email = profile['email']?.toString() ?? '';
      _phone = profile['phone']?.toString() ?? '';
    }

    setState(() => _isLoading = false);
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);
    final result = await CustomerDataService.updateNotificationPreferences({
      'network_alerts': networkAlerts,
      'security_warnings': securityWarnings,
      'bill_reminders': billReminders,
      'promotional_offers': promotionalOffers,
    });
    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.success ? 'Preferences saved' : result.message),
      backgroundColor: result.success ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _toggleAndSave(String field, bool value) {
    setState(() {
      switch (field) {
        case 'network_alerts':
          networkAlerts = value;
        case 'security_warnings':
          securityWarnings = value;
        case 'bill_reminders':
          billReminders = value;
        case 'promotional_offers':
          promotionalOffers = value;
      }
    });
    _savePreferences();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
          title: const Text('Notification Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFFFDB612))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Notification Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroSection(isDarkMode),
            _buildSectionHeader('Account & Performance'),
            _buildSettingTile(
              'Network Alerts',
              'Stay updated on maintenance and outages in your area.',
              Icons.language,
              const Color(0xFFFDB612),
              networkAlerts,
              (val) => _toggleAndSave('network_alerts', val),
              isDarkMode,
            ),
            _buildSettingTile(
              'Security Warnings',
              'Alerts regarding unauthorized logins or network threats.',
              Icons.shield_outlined,
              Colors.red,
              securityWarnings,
              (val) => _toggleAndSave('security_warnings', val),
              isDarkMode,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Divider(),
            ),
            _buildSectionHeader('Billing & Updates'),
            _buildSettingTile(
              'Bill Reminders',
              'Get notified when your monthly invoice is ready or due.',
              Icons.receipt_long,
              Colors.blue,
              billReminders,
              (val) => _toggleAndSave('bill_reminders', val),
              isDarkMode,
            ),
            _buildSettingTile(
              'Promotional Offers',
              'Exclusive deals and Fiber Jet speed upgrades.',
              Icons.sell_outlined,
              Colors.orange,
              promotionalOffers,
              (val) => _toggleAndSave('promotional_offers', val),
              isDarkMode,
            ),
            const SizedBox(height: 24),
            _buildDeliveryChannels(isDarkMode),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: const Color(0xFFFDB612).withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Fiber Jet Preferences', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Manage how and when you hear from us regarding your high-speed connection.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          if (_isSaving) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(color: Color(0xFFFDB612)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
      ),
    );
  }

  Widget _buildSettingTile(String title, String subtitle, IconData icon, Color color, bool value, ValueChanged<bool> onChanged, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFFFDB612),
        ),
      ),
    );
  }

  Widget _buildDeliveryChannels(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Delivery Channels', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 16),
            _buildChannelRow('Push Notifications', 'Active', Colors.green),
            const Divider(height: 24),
            _buildChannelRow('Email', _email.isNotEmpty ? _email : 'Not set', Colors.grey),
            const Divider(height: 24),
            _buildChannelRow('SMS', _phone.isNotEmpty ? _phone : 'Not set', Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            color: valueColor == Colors.green ? const Color(0xFFFDB612) : Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
