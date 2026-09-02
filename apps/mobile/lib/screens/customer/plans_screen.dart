import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fiberjet/services/customer_data_service.dart';
import 'package:fiberjet/services/customer_provider.dart';
import 'package:fiberjet/services/api_service.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _allPlans = [];
  List<String> _categories = [];
  TabController? _tabController;
  String? _selectedPlanId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchPlans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await CustomerDataService.getPlans();

    if (result.success && result.data != null) {
      final data = result.data as Map<String, dynamic>;
      final plans = data['plans'] as List<dynamic>? ?? [];
      final categories = (data['categories'] as List<dynamic>?)
              ?.map((c) => c.toString())
              .toList() ??
          [];

      // Add "All" as the first tab
      final allCategories = ['All', ...categories];

      setState(() {
        _allPlans = plans;
        _categories = allCategories;
        _tabController?.dispose();
        _tabController = TabController(length: allCategories.length, vsync: this);
        _tabController!.addListener(() {
          if (!_tabController!.indexIsChanging) setState(() {});
        });
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result.message;
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredPlans {
    if (_tabController == null || _tabController!.index == 0) return _allPlans;
    final selectedCategory = _categories[_tabController!.index];
    return _allPlans
        .where((p) => (p['category'] ?? '') == selectedCategory)
        .toList();
  }

  Future<void> _buyPlan(Map<String, dynamic> plan) async {
    final planId = plan['id']?.toString();
    if (planId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Purchase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You are about to buy this plan:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9B515).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF9B515).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: Color(0xFFF9B515)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan['name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '${plan['speed_mbps'] ?? 0} Mbps • ₹${plan['price'] ?? 0}',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'If you have an active plan, this new plan will be queued and activate after the current one expires.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF9B515),
              foregroundColor: const Color(0xFF0A2540),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    final res = await CustomerDataService.buyPlan(planId);

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final customerProvider = context.watch<CustomerProvider>();
    final activePlan = customerProvider.dashboardData?['active_plan'];

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Manage Plan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF9B515)))
          : _errorMessage != null
              ? _buildErrorState()
              : Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _fetchPlans,
                      color: const Color(0xFFF9B515),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 140),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (activePlan != null) _buildCurrentPlanCard(isDarkMode, activePlan),
                            if (_categories.isNotEmpty) _buildCategoryTabs(isDarkMode),
                            const SizedBox(height: 8),
                            _buildPlansList(isDarkMode, activePlan),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedPlanId != null) _buildFixedFooter(isDarkMode),
                    if (_isSubmitting)
                      Container(
                        color: Colors.black45,
                        child: const Center(
                          child: CircularProgressIndicator(color: Color(0xFFF9B515)),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchPlans,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF9B515),
                foregroundColor: const Color(0xFF0A2540),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPlanCard(bool isDarkMode, Map<String, dynamic> activePlan) {
    final planName = activePlan['plan_name'] ?? 'Unknown Plan';
    final speed = activePlan['speed_mbps'] is num 
        ? (activePlan['speed_mbps'] as num) 
        : (int.tryParse(activePlan['speed_mbps']?.toString() ?? '') ?? 0);
    final price = activePlan['price'] ?? 0;
    final expiryDate = activePlan['expiry_date'] != null
        ? DateTime.tryParse(activePlan['expiry_date'].toString())
        : null;
    final daysLeft = expiryDate != null ? expiryDate.difference(DateTime.now()).inDays : 0;

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Current Plan',
                          style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    planName,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Icon(Icons.router, color: Colors.white, size: 40),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSpeedInfo('Download', '${speed.toInt()}', 'Mbps'),
              const SizedBox(width: 48),
              _buildSpeedInfo('Upload', '${speed.toInt()}', 'Mbps'),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                daysLeft > 0 ? 'Renews in $daysLeft days' : 'Renewal date pending',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '₹$price',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(
                      text: '/mo',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedInfo(String label, String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryTabs(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
          borderRadius: BorderRadius.circular(32),
        ),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicator: BoxDecoration(
            color: isDarkMode ? const Color(0xFFF9B515) : const Color(0xFF0A2540),
            borderRadius: BorderRadius.circular(32),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: isDarkMode ? const Color(0xFF0A2540) : Colors.white,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          dividerColor: Colors.transparent,
          padding: const EdgeInsets.all(4),
          tabs: _categories.map((c) {
            final count = c == 'All'
                ? _allPlans.length
                : _allPlans.where((p) => (p['category'] ?? '') == c).length;
            return Tab(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('$c ($count)'),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPlansList(bool isDarkMode, Map<String, dynamic>? activePlan) {
    final plans = _filteredPlans;
    final currentPlanId = activePlan?['plan_id']?.toString();

    if (plans.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.wifi_off, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text('No plans available in this category',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index] as Map<String, dynamic>;
        final planId = plan['id']?.toString();
        final isCurrentPlan = planId == currentPlanId;
        final isSelected = _selectedPlanId == planId;
        final isFeatured = (plan['badge'] != null && plan['badge'].toString().isNotEmpty);

        return _buildPlanCard(plan, isDarkMode, isCurrentPlan, isSelected, isFeatured);
      },
    );
  }

  Widget _buildPlanCard(
    Map<String, dynamic> plan,
    bool isDarkMode,
    bool isCurrentPlan,
    bool isSelected,
    bool isFeatured,
  ) {
    final name = plan['name'] ?? 'Unknown Plan';
    final description = plan['description'] ?? '';
    final speed = _toNum(plan['speed_mbps']);
    final price = plan['price'] ?? 0;
    final badge = plan['badge']?.toString() ?? '';
    final dataLimitRaw = plan['data_limit_gb'];
    final dataPerDayRaw = plan['data_per_day_gb'];
    final validityDays = plan['validity_days'] ?? 30;
    final cloudStorage = _toNum(plan['cloud_storage_gb']);
    final category = plan['category'] ?? '';
    final ottBenefits = plan['ott_benefits'];
    final dataLimit = dataLimitRaw != null ? _toNum(dataLimitRaw) : null;
    final dataPerDay = dataPerDayRaw != null ? _toNum(dataPerDayRaw) : null;

    // Count OTT platforms
    int ottCount = 0;
    if (ottBenefits is List) {
      ottCount = ottBenefits.length;
    } else if (ottBenefits is Map) {
      ottCount = ottBenefits.length;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCurrentPlan
            ? (isDarkMode ? const Color(0xFF0F2A1A) : const Color(0xFFF0FFF0))
            : isSelected
                ? (isDarkMode ? const Color(0xFF231D0F) : const Color(0xFFFFF8E6))
                : (isDarkMode ? const Color(0xFF1F2937) : Colors.white),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCurrentPlan
              ? Colors.greenAccent.withValues(alpha: 0.5)
              : isSelected
                  ? const Color(0xFFF9B515).withValues(alpha: 0.5)
                  : isFeatured
                      ? const Color(0xFFF9B515).withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.1),
          width: isCurrentPlan || isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge + Category Row
          Row(
            children: [
              if (isCurrentPlan)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '✓ CURRENT PLAN',
                    style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              if (badge.isNotEmpty && !isCurrentPlan)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9B515),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge.toUpperCase(),
                    style: const TextStyle(color: Color(0xFF0A2540), fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  category,
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Plan Name + Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    if (description.isNotEmpty)
                      Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹$price', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(
                    '$validityDays days',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Features Row
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildFeatureChip(Icons.speed, '${speed.toInt()} Mbps'),
              if (dataLimit != null && dataLimit > 0)
                _buildFeatureChip(Icons.data_usage, '$dataLimit GB'),
              if (dataPerDay != null && dataPerDay > 0)
                _buildFeatureChip(Icons.today, '$dataPerDay GB/day'),
              if (dataLimit == null || dataLimit == 0)
                _buildFeatureChip(Icons.all_inclusive, 'Unlimited'),
              if (cloudStorage > 0)
                _buildFeatureChip(Icons.cloud, '$cloudStorage GB Cloud'),
              if (ottCount > 0)
                _buildFeatureChip(Icons.movie, '$ottCount OTT Apps'),
            ],
          ),

          // Select Button (only if not current plan)
          if (!isCurrentPlan) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: isSelected
                  ? ElevatedButton.icon(
                      onPressed: () => _buyPlan(plan),
                      icon: const Icon(Icons.shopping_cart, size: 18),
                      label: const Text('Buy Plan', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF9B515),
                        foregroundColor: const Color(0xFF0A2540),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                    )
                  : OutlinedButton(
                      onPressed: () => setState(() => _selectedPlanId = plan['id']?.toString()),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isFeatured
                              ? const Color(0xFFF9B515)
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: isFeatured ? const Color(0xFFF9B515) : null,
                      ),
                      child: const Text('Select Plan', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  /// Safely convert a dynamic JSON value to num (handles int, double, String, null).
  num _toNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? 0;
  }

  Widget _buildFeatureChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF9B515).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFF9B515), size: 14),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFixedFooter(bool isDarkMode) {
    final selectedPlan = _allPlans.firstWhere(
      (p) => p['id']?.toString() == _selectedPlanId,
      orElse: () => null,
    );

    if (selectedPlan == null) return const SizedBox.shrink();

    final price = selectedPlan['price'] ?? 0;
    final name = selectedPlan['name'] ?? '';
    final validity = selectedPlan['validity_days'] ?? 30;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1A160B) : Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SELECTED PLAN',
                          style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                      Text(
                        name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '₹$price',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(
                              text: '  ',
                            ),
                            TextSpan(
                              text: '/$validity days',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _selectedPlanId = null),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => _buyPlan(selectedPlan),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF9B515),
                        foregroundColor: const Color(0xFF0A2540),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Buy Plan', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(width: 8),
                          Icon(Icons.shopping_cart, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
