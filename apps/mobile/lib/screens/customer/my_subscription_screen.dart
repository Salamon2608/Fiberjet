import 'package:flutter/material.dart';
import 'package:fiberjet/services/customer_data_service.dart';
import 'package:fiberjet/screens/customer/plans_screen.dart';
import 'package:intl/intl.dart';

class MySubscriptionScreen extends StatefulWidget {
  const MySubscriptionScreen({super.key});

  @override
  State<MySubscriptionScreen> createState() => _MySubscriptionScreenState();
}

class _MySubscriptionScreenState extends State<MySubscriptionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _subscriptionsData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchSubscriptions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchSubscriptions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await CustomerDataService.getMySubscriptions();
    if (result.success && result.data != null) {
      setState(() {
        _subscriptionsData = result.data as Map<String, dynamic>;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result.message;
        _isLoading = false;
      });
    }
  }

  num _parseNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Subscriptions'),
        backgroundColor: const Color(0xFF0A2540),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFDB813),
          labelColor: const Color(0xFFFDB813),
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Upcoming'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _buildBody(isDarkMode),
    );
  }

  Widget _buildBody(bool isDarkMode) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchSubscriptions,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDB813), foregroundColor: Colors.black),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildActiveTab(isDarkMode),
        _buildUpcomingTab(isDarkMode),
        _buildHistoryTab(isDarkMode),
      ],
    );
  }

  Widget _buildActiveTab(bool isDarkMode) {
    final activePlan = _subscriptionsData?['active_plan'];

    if (activePlan == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No Active Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PlansScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFDB813),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('View Available Plans'),
            ),
          ],
        ),
      );
    }

    final planName = activePlan['plan_name'] ?? 'Unknown Plan';
    final speed = _parseNum(activePlan['speed_mbps']);
    final dataUsedGb = _parseNum(activePlan['data_used_gb']);
    final dataLimitGb = _parseNum(activePlan['data_limit_gb']);
    final hasDataLimit = dataLimitGb > 0;
    
    final startDateStr = activePlan['start_date'];
    final expiryDateStr = activePlan['expiry_date'];
    final startDate = startDateStr != null ? DateTime.tryParse(startDateStr.toString()) : null;
    final expiryDate = expiryDateStr != null ? DateTime.tryParse(expiryDateStr.toString()) : null;

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

    final dataLeftGb = activePlan['data_left_gb'] != null
        ? _parseNum(activePlan['data_left_gb']).toDouble()
        : (hasDataLimit ? (dataLimitGb - dataUsedGb).clamp(0.0, dataLimitGb) : 0.0);
    
    final ottBenefits = activePlan['ott_benefits'];

    return RefreshIndicator(
      onRefresh: _fetchSubscriptions,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1F2937) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(planName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('ACTIVE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 150,
                    width: 150,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: hasDataLimit ? dataProgress.toDouble() : timeProgress.toDouble(),
                          strokeWidth: 12,
                          backgroundColor: isDarkMode ? Colors.white10 : Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFDB813)),
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                hasDataLimit ? '${dataLeftGb.toInt()} GB' : '$daysLeft Days',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              Text(hasDataLimit ? 'Left' : 'Remaining', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoColumn('Speed', '${speed}Mbps', Icons.speed),
                      _buildInfoColumn('Data', hasDataLimit ? '${dataLimitGb.toInt()}GB' : 'Unlimited', Icons.data_usage),
                      _buildInfoColumn('Validity', '$daysLeft Days', Icons.event),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Plan Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildDetailRow('Start Date', startDateStr != null ? DateFormat.yMMMd().format(DateTime.parse(startDateStr)) : 'N/A'),
            _buildDetailRow('Expiry Date', expiryDateStr != null ? DateFormat.yMMMd().format(DateTime.parse(expiryDateStr)) : 'N/A'),
            if (ottBenefits != null && ottBenefits is List && ottBenefits.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Included Benefits', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...ottBenefits.map((benefit) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(benefit.toString()),
                  ],
                ),
              )).toList(),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PlansScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFDB813),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Recharge / Change Plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingTab(bool isDarkMode) {
    final upcomingPlans = _subscriptionsData?['upcoming_plans'] as List<dynamic>? ?? [];

    if (upcomingPlans.isEmpty) {
      return const Center(child: Text('No upcoming plans queued.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: upcomingPlans.length,
      itemBuilder: (context, index) {
        final plan = upcomingPlans[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const CircleAvatar(
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.queue, color: Colors.white),
            ),
            title: Text(plan['plan_name'] ?? 'Unknown Plan', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Speed: ${plan['speed_mbps']} Mbps'),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(plan['status']?.toString().toUpperCase() ?? 'QUEUED', style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            trailing: Text('₹${plan['price']}'),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(bool isDarkMode) {
    final history = _subscriptionsData?['history'] as List<dynamic>? ?? [];

    if (history.isEmpty) {
      return const Center(child: Text('No plan history found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final plan = history[index];
        final expiryDateStr = plan['expiry_date'];
        final expiryStr = expiryDateStr != null ? DateFormat.yMMMd().format(DateTime.parse(expiryDateStr)) : 'Unknown';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.history),
            title: Text(plan['plan_name'] ?? 'Unknown Plan', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Expired: $expiryStr'),
            trailing: Text('₹${plan['price']}'),
          ),
        );
      },
    );
  }

  Widget _buildInfoColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
