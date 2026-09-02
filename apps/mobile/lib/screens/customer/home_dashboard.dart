import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:fiberjet/screens/customer/speed_test_screen.dart';
import 'package:fiberjet/screens/customer/network_scanner_screen.dart';
import 'package:fiberjet/screens/customer/ott_claims_screen.dart';
import 'package:fiberjet/screens/customer/cloud_drive_screen.dart';
import 'package:fiberjet/screens/customer/modem_info_screen.dart';
import 'package:fiberjet/screens/customer/notification_settings_screen.dart';
import 'package:fiberjet/screens/customer/my_subscription_screen.dart';
import 'package:fiberjet/screens/customer/support_tickets_screen.dart';
import 'package:intl/intl.dart';

import 'package:provider/provider.dart';
import 'package:fiberjet/services/customer_provider.dart';
import 'package:fiberjet/services/auth_provider.dart';
import 'dart:async';
import 'package:fiberjet/services/customer_data_service.dart';
import 'package:fiberjet/services/api_service.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  int _currentAdIndex = 0;
  final PageController _pageController = PageController();
  final Set<String> _reportedImpressions = {};
  Timer? _carouselTimer;
  List<dynamic>? _lastAds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().fetchDashboard();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  void _startCarouselTimer(List<dynamic> ads) {
    _carouselTimer?.cancel();
    if (ads.length <= 1) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        final nextPage = (_pageController.page!.round() + 1) % ads.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _checkAndStartTimer(List<dynamic> ads) {
    if (ads.isEmpty) return;
    if (_lastAds == null || _lastAds!.length != ads.length) {
      _lastAds = ads;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startCarouselTimer(ads);
        final firstAdId = ads[0]['id']?.toString();
        if (firstAdId != null && !_reportedImpressions.contains(firstAdId)) {
          _reportedImpressions.add(firstAdId);
          CustomerDataService.recordAdImpression(firstAdId);
        }
      });
    }
  }

  void _onAdPageChanged(int index, List<dynamic> ads) {
    setState(() {
      _currentAdIndex = index;
    });
    if (index >= 0 && index < ads.length) {
      final adId = ads[index]['id']?.toString();
      if (adId != null && !_reportedImpressions.contains(adId)) {
        _reportedImpressions.add(adId);
        CustomerDataService.recordAdImpression(adId);
      }
    }
  }

  void _onAdTapped(dynamic ad) {
    final adId = ad['id']?.toString();
    if (adId != null) {
      CustomerDataService.recordAdClick(adId);
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A2540),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.campaign, color: Color(0xFFFDB813), size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ad['title']?.toString() ?? 'Special Offer',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ad['image_path'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  ad['image_path'].toString().startsWith('http')
                      ? ad['image_path']
                      : '${ApiService.baseUrl}${ad['image_path']}',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white24,
                    size: 48,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Thank you for showing interest in our special promotion! A FiberJet representative will get in touch with you shortly to help you activate this campaign benefit on your account.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFDB813),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Great, thanks!'),
          ),
        ],
      ),
    );
  }

  Future<void> _onRefresh() async {
    await context.read<CustomerProvider>().fetchDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final customerProvider = context.watch<CustomerProvider>();
    final dashboardData = customerProvider.dashboardData;
    final user = dashboardData?['user'];
    final activePlan = dashboardData?['active_plan'];
    final activeAds = dashboardData?['active_ads'] as List<dynamic>? ?? [];
    final activeComplaints = dashboardData?['active_complaints'] as List<dynamic>? ?? [];

    if (customerProvider.isLoading && dashboardData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (customerProvider.errorMessage != null && dashboardData == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: ${customerProvider.errorMessage}', textAlign: TextAlign.center),
              ),
              const SizedBox(height: 16),
              if (customerProvider.errorMessage!.toLowerCase().contains('token') || 
                  customerProvider.errorMessage!.toLowerCase().contains('authenticat'))
                ElevatedButton(
                  onPressed: () async {
                    await context.read<AuthProvider>().logout();
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pushReplacementNamed('/login');
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDB813), foregroundColor: Colors.black),
                  child: const Text('Login Again'),
                )
              else
                ElevatedButton(
                  onPressed: () => customerProvider.fetchDashboard(),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDB813), foregroundColor: Colors.black),
                  child: const Text('Retry'),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(context, isDarkMode, user),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Transform.translate(
                  offset: const Offset(0, -50),
                  child: Column(
                    children: [
                      _buildPlanCard(isDarkMode, activePlan),
                      if (activeComplaints.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildActiveVisitsCard(context, isDarkMode, activeComplaints),
                      ],
                      const SizedBox(height: 24),
                      _buildQuickActions(context, isDarkMode),
                      const SizedBox(height: 24),
                      _buildPromotionsCarousel(isDarkMode, activeAds),
                      if (activeAds.isNotEmpty) const SizedBox(height: 24),
                      _buildSecurityPromo(isDarkMode),
                      const SizedBox(height: 24),
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

  Widget _buildHeader(BuildContext context, bool isDarkMode, Map<String, dynamic>? user) {
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 80),
      decoration: BoxDecoration(
        color: const Color(0xFF0A2540),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome back,',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        user?['name'] ?? 'Guest',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationSettingsScreen()),
                  );
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.bolt, color: Color(0xFFFDB813), size: 32),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.wifi, color: Color(0xFFFDB813), size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Fiber Jet_5G',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Online',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildPlanCard(bool isDarkMode, Map<String, dynamic>? activePlan) {
    if (activePlan == null) {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MySubscriptionScreen())),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1F2937) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: const Center(child: Text('No active plan found. Tap to subscribe.')),
        ),
      );
    }
    final planName = activePlan['plan_name'] ?? 'Unknown Plan';
    final speed = _parseNum(activePlan['speed_mbps']);
    final status = activePlan['status'] ?? 'inactive';
    final dataUsedGb = _parseNum(activePlan['data_used_gb']);
    final dataLimitGb = _parseNum(activePlan['data_limit_gb']);
    final hasDataLimit = dataLimitGb > 0;
    
    final startDateStr = activePlan['start_date'];
    final startDate = startDateStr != null ? DateTime.tryParse(startDateStr.toString()) : null;
    final expiryDate = activePlan['expiry_date'] != null ? DateTime.tryParse(activePlan['expiry_date'].toString()) : null;

    final daysLeft = activePlan['days_left'] != null
        ? _parseNum(activePlan['days_left']).toInt()
        : (expiryDate != null ? (expiryDate.difference(DateTime.now()).inHours / 24).ceil() : 0);

    final totalDays = (startDate != null && expiryDate != null) ? expiryDate.difference(startDate).inDays : 30;

    final passedDays = totalDays - daysLeft;
    final timeProgress = activePlan['time_progress'] != null
        ? _parseNum(activePlan['time_progress']).toDouble()
        : (totalDays > 0 ? (passedDays / totalDays).clamp(0.0, 1.0) : 0.0);

    final dataProgress = activePlan['data_progress'] != null
        ? _parseNum(activePlan['data_progress']).toDouble()
        : (hasDataLimit ? ((dataLimitGb - dataUsedGb) / dataLimitGb).clamp(0.0, 1.0) : 0.0);

    final dataPercent = activePlan['data_percent'] != null
        ? _parseNum(activePlan['data_percent']).toDouble()
        : (dataProgress * 100);

    final dataLeftGb = activePlan['data_left_gb'] != null
        ? _parseNum(activePlan['data_left_gb']).toDouble()
        : (hasDataLimit ? (dataLimitGb - dataUsedGb).clamp(0.0, dataLimitGb) : 0.0);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MySubscriptionScreen())),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Premium ${speed}Mbps Plan',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white10 : const Color(0xFF0A2540).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  hasDataLimit ? 'Data Remaining' : 'Subscription Validity',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                Text(
                  hasDataLimit ? '${dataPercent.toInt()}% Left' : '$daysLeft Days Left',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFDB813)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: hasDataLimit ? dataProgress : timeProgress,
                minHeight: 10,
                backgroundColor: isDarkMode ? Colors.white10 : Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFDB813)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  hasDataLimit 
                      ? '${dataLeftGb.toInt()} GB Left' 
                      : 'Started: ${startDate != null ? DateFormat.yMMMd().format(startDate) : "N/A"}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  hasDataLimit 
                      ? '${dataLimitGb.toInt()} GB Limit' 
                      : 'Expires: ${expiryDate != null ? DateFormat.yMMMd().format(expiryDate) : "N/A"}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                const Text(
                  'Expires in ',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '$daysLeft days',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 12),
          child: Text(
            'Quick Actions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildSmallActionCard(
              context,
              'Device Info',
              Icons.router,
              Colors.purple,
              isDarkMode,
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ModemInfoScreen())),
            ),
            _buildSmallActionCard(
              context,
              'Speed Test',
              Icons.speed,
              Colors.blue,
              isDarkMode,
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SpeedTestScreen())),
            ),
            _buildSmallActionCard(
              context,
              'Cloud Drive',
              Icons.cloud_upload,
              Colors.orange,
              isDarkMode,
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CloudDriveScreen())),
            ),
            _buildSmallActionCard(
              context,
              'OTT Benefits',
              Icons.live_tv,
              Colors.green,
              isDarkMode,
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OttClaimsScreen())),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color bgColor,
    Color textColor,
    VoidCallback onTap, {
    bool isWide = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: bgColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 10),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: textColor, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallActionCard(BuildContext context, String title, IconData icon, Color color, bool isDarkMode, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityPromo(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A2540), Color(0xFF163C63)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2540).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'SECURITY',
                style: TextStyle(color: Color(0xFFFDB813), fontSize: 10, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Spam-Free Internet',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Enable Shield+',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.security, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  /// Safely convert a dynamic JSON value to num.
  num _parseNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? 0;
  }

  Widget _buildPromotionsCarousel(bool isDarkMode, List<dynamic> ads) {
    if (ads.isEmpty) return const SizedBox.shrink();

    _checkAndStartTimer(ads);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 12),
          child: Text(
            'Special Promotions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => _onAdPageChanged(index, ads),
            itemCount: ads.length,
            itemBuilder: (context, index) {
              final ad = ads[index];
              final title = ad['title']?.toString() ?? 'Special Offer';
              final imagePath = ad['image_path']?.toString();

              return GestureDetector(
                onTap: () => _onAdTapped(ad),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D2D54), Color(0xFF1E4C7A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A2540).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      if (imagePath != null)
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.6,
                            child: Image.network(
                              imagePath.startsWith('http')
                                  ? imagePath
                                  : '${ApiService.baseUrl}$imagePath',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFF0F2646),
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white12,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.8),
                                Colors.transparent,
                              ],
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDB813).withOpacity(0.9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'LIMITED OFFER',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: const [
                                Text(
                                  'Tap to claim benefits',
                                  style: TextStyle(
                                    color: Color(0xFFFDB813),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward,
                                  color: Color(0xFFFDB813),
                                  size: 14,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        if (ads.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              ads.length,
              (index) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentAdIndex == index
                      ? const Color(0xFFFDB813)
                      : Colors.grey.withOpacity(0.5),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActiveVisitsCard(BuildContext context, bool isDarkMode, List<dynamic> complaints) {
    final active = complaints.first as Map<String, dynamic>;
    final isVerified = active['is_otp_verified'] == true;
    final otp = active['visit_otp']?.toString() ?? '';
    final title = active['title']?.toString() ?? 'Support Request';
    final category = active['category']?.toString() ?? 'Technical Support';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isVerified
              ? Colors.green.withValues(alpha: 0.4)
              : const Color(0xFFF9B515).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isVerified
                ? Colors.green.withValues(alpha: 0.08)
                : const Color(0xFFF9B515).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isVerified
                          ? Colors.green.withValues(alpha: 0.15)
                          : const Color(0xFFF9B515).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isVerified ? Icons.verified_user : Icons.pin,
                      color: isVerified ? Colors.green : const Color(0xFFD97706),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVerified ? 'TECHNICIAN REACHED' : 'ACTIVE SERVICE VISIT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: isVerified ? Colors.green : const Color(0xFFD97706),
                        ),
                      ),
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SupportTicketsScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? const Color(0xFFF9B515) : const Color(0xFF0A2540),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: isDarkMode ? const Color(0xFFF9B515) : const Color(0xFF0A2540),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          if (otp.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDarkMode ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVerified ? 'Arrival Verified' : 'Share OTP with Technician',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isVerified ? Colors.green : Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (isVerified)
                          const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Technician marked as reached',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            otp.split('').join('  '),
                            style: const TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              color: Color(0xFFD97706),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!isVerified)
                    ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: otp));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Arrival OTP $otp copied to clipboard!'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 14),
                      label: const Text('Copy OTP'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF9B515),
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}


