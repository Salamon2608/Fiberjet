import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fiberjet/services/auth_provider.dart';
import 'package:fiberjet/services/storage_service.dart';
import 'package:fiberjet/services/customer_data_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<dynamic> _plans = [];
  Map<String, dynamic>? _selectedPlan;
  bool _isLoadingPlans = true;
  bool _isActivated = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() { _isLoadingPlans = true; });
    final res = await CustomerDataService.getPlans();
    if (res.success && res.data != null) {
      final plansList = res.data['plans'] as List?;
      if (plansList != null && plansList.isNotEmpty) {
        setState(() {
          _plans = plansList;
          _selectedPlan = plansList.first as Map<String, dynamic>;
          _isLoadingPlans = false;
        });
        return;
      }
    }
    setState(() { _isLoadingPlans = false; });
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skip() => _completeOnboarding();

  Future<void> _completeOnboarding() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?['id']?.toString();
    await StorageService.setOnboardingComplete(userId);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/customer', (route) => false);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A2540),
      body: Stack(
        children: [
          // Subtle background grid
          Positioned.fill(
            child: Opacity(
              opacity: 0.04,
              child: CustomPaint(painter: _GridPainter()),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top bar with skip
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Page indicator text
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          'Step ${_currentPage + 1} of 3',
                          key: ValueKey(_currentPage),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_currentPage < 2)
                        TextButton(
                          onPressed: _skip,
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Pages
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      const _ConnectModemPage(),
                      _ChoosePlanPage(
                        plans: _plans,
                        selectedPlan: _selectedPlan,
                        onPlanSelected: (plan) => setState(() => _selectedPlan = plan),
                        isLoading: _isLoadingPlans,
                      ),
                      _PaymentActivationPage(
                        selectedPlan: _selectedPlan,
                        onActivated: () => setState(() => _isActivated = true),
                      ),
                    ],
                  ),
                ),
                // Bottom section: dots + button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    children: [
                      // Dot indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          final isActive = i == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            width: isActive ? 32 : 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFFF9B515)
                                  : Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 32),
                      // Main action button
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: (_currentPage == 2 && !_isActivated) ? null : _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF9B515),
                            disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                            foregroundColor: const Color(0xFF0A2540),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Row(
                              key: ValueKey('btn_${_currentPage}_$_isActivated'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentPage == 2
                                      ? 'Get Started'
                                      : 'Continue',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  _currentPage == 2
                                      ? Icons.rocket_launch
                                      : Icons.arrow_forward,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

// ============================================================
// PAGE 1 — Connect to Modem
// ============================================================
class _ConnectModemPage extends StatefulWidget {
  const _ConnectModemPage();

  @override
  State<_ConnectModemPage> createState() => _ConnectModemPageState();
}

class _ConnectModemPageState extends State<_ConnectModemPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late AnimationController _connectController;
  late Animation<double> _connectAnimation;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _connectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _connectAnimation = CurvedAnimation(
      parent: _connectController,
      curve: Curves.elasticOut,
    );

    // Simulate auto-connect after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isConnected = true);
        _connectController.forward();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    _connectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 1),
          // Animated WiFi illustration
          SizedBox(
            height: 280,
            width: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulse rings
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(280, 280),
                      painter: _WifiPulsePainter(
                        progress: _pulseController.value,
                        isConnected: _isConnected,
                      ),
                    );
                  },
                ),
                // Scanning dots orbiting
                if (!_isConnected)
                  AnimatedBuilder(
                    animation: _scanController,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(280, 280),
                        painter: _OrbitDotsPainter(
                          progress: _scanController.value,
                        ),
                      );
                    },
                  ),
                // Center router icon
                AnimatedBuilder(
                  animation: _connectAnimation,
                  builder: (context, child) {
                    final scale = _isConnected
                        ? 1.0 + (_connectAnimation.value * 0.15)
                        : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _isConnected
                                ? [const Color(0xFF22C55E), const Color(0xFF16A34A)]
                                : [const Color(0xFFF9B515), const Color(0xFFF59E0B)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_isConnected
                                      ? const Color(0xFF22C55E)
                                      : const Color(0xFFF9B515))
                                  .withValues(alpha: 0.4),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isConnected ? Icons.check_rounded : Icons.router,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          // Title
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Text(
              _isConnected ? 'Connected!' : 'Connect Your Router',
              key: ValueKey(_isConnected),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Text(
              _isConnected
                  ? 'Your Fiber Jet router is online and ready.\nLet\'s set up your plan!'
                  : 'Connect your Fiber Jet router to your\nmodem for hyper-speed internet access.',
              key: ValueKey('desc_$_isConnected'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Status badge
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _isConnected
                  ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                  : const Color(0xFFF9B515).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isConnected
                    ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                    : const Color(0xFFF9B515).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isConnected)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: const Color(0xFFF9B515).withValues(alpha: 0.8),
                    ),
                  )
                else
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF22C55E),
                    size: 18,
                  ),
                const SizedBox(width: 10),
                Text(
                  _isConnected ? 'Signal: Excellent (98%)' : 'Scanning for devices...',
                  style: TextStyle(
                    color: _isConnected
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFF9B515),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// ============================================================
// PAGE 2 — Choose Your Plan
// ============================================================
class _ChoosePlanPage extends StatefulWidget {
  final List<dynamic> plans;
  final Map<String, dynamic>? selectedPlan;
  final ValueChanged<Map<String, dynamic>> onPlanSelected;
  final bool isLoading;

  const _ChoosePlanPage({
    required this.plans,
    required this.selectedPlan,
    required this.onPlanSelected,
    required this.isLoading,
  });

  @override
  State<_ChoosePlanPage> createState() => _ChoosePlanPageState();
}

class _ChoosePlanPageState extends State<_ChoosePlanPage>
    with TickerProviderStateMixin {
  late AnimationController _staggerController;
  late List<Animation<Offset>> _slideAnimations;
  late List<Animation<double>> _fadeAnimations;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _slideAnimations = List.generate(10, (i) {
      final start = i * 0.15;
      final end = start + 0.5;
      return Tween<Offset>(
        begin: const Offset(1.0, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _staggerController,
        curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOutCubic),
      ));
    });

    _fadeAnimations = List.generate(10, (i) {
      final start = i * 0.15;
      final end = start + 0.4;
      return Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _staggerController,
        curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOut),
      ));
    });

    if (!widget.isLoading) {
      _staggerController.forward();
    }
  }

  @override
  void didUpdateWidget(_ChoosePlanPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading && !widget.isLoading) {
      _staggerController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFF9B515),
        ),
      );
    }

    if (widget.plans.isEmpty) {
      return const Center(
        child: Text(
          'No active plans found.\nPlease check back later.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Text(
            'Choose Your Plan',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the perfect speed for your needs',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          // Plan cards
          Expanded(
            child: AnimatedBuilder(
              animation: _staggerController,
              builder: (context, child) {
                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: widget.plans.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    final plan = widget.plans[i] as Map<String, dynamic>;
                    final isSelected = widget.selectedPlan?['id'] == plan['id'];
                    final planId = plan['id']?.toString() ?? '$i';
                    final speedMbps = plan['speed_mbps'] is num 
                        ? (plan['speed_mbps'] as num).toInt() 
                        : (int.tryParse(plan['speed_mbps']?.toString() ?? '') ?? 100);
                    final price = plan['price'] is num 
                        ? (plan['price'] as num).toInt() 
                        : (double.tryParse(plan['price']?.toString() ?? '')?.toInt() ?? 0);
                    
                    return SlideTransition(
                      key: ValueKey(planId),
                      position: _slideAnimations[i % 10],
                      child: FadeTransition(
                        opacity: _fadeAnimations[i % 10],
                        child: GestureDetector(
                          onTap: () => widget.onPlanSelected(plan),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF1A3A5C),
                                        Color(0xFF0F2D4A),
                                      ],
                                    )
                                  : null,
                              color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFF9B515)
                                    : Colors.white.withValues(alpha: 0.08),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFF9B515).withValues(alpha: 0.15),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                // Speed icon
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 350),
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFF9B515).withValues(alpha: 0.2)
                                        : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    speedMbps < 100
                                        ? Icons.speed
                                        : speedMbps < 300
                                            ? Icons.bolt
                                            : Icons.rocket_launch,
                                    color: isSelected
                                        ? const Color(0xFFF9B515)
                                        : Colors.white.withValues(alpha: 0.5),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Plan info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              plan['name']?.toString() ?? 'Plan',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.white.withValues(alpha: 0.7),
                                              ),
                                            ),
                                          ),
                                          if (plan['badge'] != null && plan['badge'].toString().isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF9B515),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                plan['badge'].toString().toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0A2540),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "$speedMbps Mbps Speed",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isSelected
                                              ? const Color(0xFFF9B515)
                                              : Colors.white.withValues(alpha: 0.4),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Price
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '₹',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? const Color(0xFFF9B515)
                                                : Colors.white.withValues(alpha: 0.5),
                                          ),
                                        ),
                                        _AnimatedPrice(
                                          price: price,
                                          isSelected: isSelected,
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '/${plan['validity_days'] ?? 30} days',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                // Selection indicator
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFFF9B515)
                                          : Colors.white.withValues(alpha: 0.2),
                                      width: 2,
                                    ),
                                    color: isSelected
                                        ? const Color(0xFFF9B515)
                                        : Colors.transparent,
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check,
                                          size: 16, color: Color(0xFF0A2540))
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PAGE 3 — Payment & Activation
// ============================================================
class _PaymentActivationPage extends StatefulWidget {
  final Map<String, dynamic>? selectedPlan;
  final VoidCallback onActivated;

  const _PaymentActivationPage({
    required this.selectedPlan,
    required this.onActivated,
  });

  @override
  State<_PaymentActivationPage> createState() => _PaymentActivationPageState();
}

class _PaymentActivationPageState extends State<_PaymentActivationPage>
    with TickerProviderStateMixin {
  late AnimationController _cardFlipController;
  late AnimationController _checkController;
  late AnimationController _confettiController;
  late Animation<double> _flipAnimation;
  late Animation<double> _checkAnimation;

  bool _isActivated = false;
  int _selectedPayment = 0;

  static const _paymentMethods = [
    ('Credit Card', Icons.credit_card, 'Visa, Mastercard'),
    ('UPI', Icons.account_balance, 'Google Pay, PhonePe'),
    ('Wallet', Icons.account_balance_wallet, 'Paytm, Amazon Pay'),
  ];

  @override
  void initState() {
    super.initState();
    _cardFlipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _flipAnimation = CurvedAnimation(
      parent: _cardFlipController,
      curve: Curves.easeInOutBack,
    );

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _cardFlipController.dispose();
    _checkController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _activate() async {
    if (widget.selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a plan first!'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Show a loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFFF9B515)),
            SizedBox(width: 20),
            Text('Activating subscription...'),
          ],
        ),
      ),
    );

    final res = await CustomerDataService.buyPlan(widget.selectedPlan!['id']);
    
    if (mounted) {
      Navigator.pop(context); // close loading dialog
      
      if (res.success) {
        setState(() => _isActivated = true);
        _cardFlipController.forward();
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            _checkController.forward();
            _confettiController.forward();
          }
        });
        widget.onActivated();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res.message.isNotEmpty ? res.message : 'Activation failed'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedPlan == null) {
      return const Center(
        child: Text(
          'Please select a plan on the previous step.',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Text(
            'Payment & Activation',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Almost there! Complete your setup',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),

          // Card flip area
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Confetti
                if (_isActivated)
                  AnimatedBuilder(
                    animation: _confettiController,
                    builder: (context, _) {
                      return CustomPaint(
                        size: Size(MediaQuery.of(context).size.width - 48, 200),
                        painter: _ConfettiPainter(
                          progress: _confettiController.value,
                        ),
                      );
                    },
                  ),
                // Card
                AnimatedBuilder(
                  animation: _flipAnimation,
                  builder: (context, _) {
                    final angle = _flipAnimation.value * pi;
                    final isFront = angle < pi / 2;
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(angle),
                      child: isFront
                          ? _buildCardFront()
                          : Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(pi),
                              child: _buildCardBack(),
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          if (!_isActivated) ...[
            // Payment methods
            ...List.generate(3, (i) {
              final method = _paymentMethods[i];
              final isSelected = _selectedPayment == i;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedPayment = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF9B515).withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFF9B515).withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          method.$2,
                          color: isSelected
                              ? const Color(0xFFF9B515)
                              : Colors.white.withValues(alpha: 0.5),
                          size: 24,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                method.$1,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                method.$3,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFF9B515)
                                  : Colors.white.withValues(alpha: 0.2),
                              width: 2,
                            ),
                            color: isSelected
                                ? const Color(0xFFF9B515)
                                : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  size: 14, color: Color(0xFF0A2540))
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            // Activate button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _activate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Activate Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Success message
            AnimatedBuilder(
              animation: _checkAnimation,
              builder: (context, _) {
                return Transform.scale(
                  scale: _checkAnimation.value.clamp(0.0, 1.0),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Color(0xFF22C55E),
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'You\'re All Set! 🎉',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your Fiber Jet connection is active.\nTap "Get Started" to explore!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.6),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardFront() {
    final planName = widget.selectedPlan?['name']?.toString() ?? 'Plan';
    final price = widget.selectedPlan?['price'] is num 
        ? (widget.selectedPlan!['price'] as num).toInt() 
        : (double.tryParse(widget.selectedPlan?['price']?.toString() ?? '')?.toInt() ?? 0);
    
    return Container(
      width: double.infinity,
      height: 190,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A3A5C), Color(0xFF0F2D4A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF9B515).withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF9B515).withValues(alpha: 0.1),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(
                Icons.wifi,
                color: Color(0xFFF9B515),
                size: 28,
              ),
              Text(
                'FIBER JET',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          Text(
            '•••• •••• •••• 4289',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 20,
              letterSpacing: 3,
              fontFamily: 'monospace',
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planName.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      '₹$price',
                      style: const TextStyle(
                        color: Color(0xFFF9B515),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.contactless,
                color: Color(0xFFF9B515),
                size: 32,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    return Container(
      width: double.infinity,
      height: 190,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF166534), Color(0xFF15803D)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withValues(alpha: 0.2),
            blurRadius: 24,
          ),
        ],
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified,
              color: Colors.white,
              size: 56,
            ),
            SizedBox(height: 12),
            Text(
              'PAYMENT CONFIRMED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Animated Price Counter Widget
// ============================================================
class _AnimatedPrice extends StatelessWidget {
  final int price;
  final bool isSelected;

  const _AnimatedPrice({required this.price, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: price),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Text(
          '$value',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFFF9B515) : Colors.white,
          ),
        );
      },
    );
  }
}

// ============================================================
// Custom Painters
// ============================================================

/// WiFi pulse rings emanating from center
class _WifiPulsePainter extends CustomPainter {
  final double progress;
  final bool isConnected;

  _WifiPulsePainter({required this.progress, required this.isConnected});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final color = isConnected ? const Color(0xFF22C55E) : const Color(0xFFF9B515);

    for (int i = 0; i < 4; i++) {
      final ringProgress = (progress + i * 0.25) % 1.0;
      final radius = 45.0 + ringProgress * 100;
      final opacity = (1.0 - ringProgress) * 0.35;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WifiPulsePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isConnected != isConnected;
}

/// Orbiting dots for scanning effect
class _OrbitDotsPainter extends CustomPainter {
  final double progress;

  _OrbitDotsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const dotCount = 6;
    const radius = 90.0;

    for (int i = 0; i < dotCount; i++) {
      final angle = (progress * 2 * pi) + (i * 2 * pi / dotCount);
      final dx = center.dx + cos(angle) * radius;
      final dy = center.dy + sin(angle) * radius;
      final opacity = (0.3 + (sin(progress * 2 * pi + i) + 1) / 2 * 0.5);

      final paint = Paint()
        ..color = const Color(0xFFF9B515).withValues(alpha: opacity.clamp(0.0, 1.0));

      canvas.drawCircle(Offset(dx, dy), 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitDotsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Confetti particles
class _ConfettiPainter extends CustomPainter {
  final double progress;
  final _random = Random(42); // fixed seed for consistent particles

  _ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFFF9B515),
      const Color(0xFF22C55E),
      const Color(0xFF3B82F6),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      Colors.white,
    ];

    for (int i = 0; i < 40; i++) {
      final startX = _random.nextDouble() * size.width;
      final startY = -20.0;
      final endY = size.height + 40;
      final speed = 0.5 + _random.nextDouble() * 0.5;
      final drift = (_random.nextDouble() - 0.5) * 80;

      final y = startY + (endY - startY) * progress * speed;
      final x = startX + drift * sin(progress * pi * 2 + i);
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final rotation = progress * pi * (2 + _random.nextDouble() * 2);

      if (y > size.height || y < -20) continue;

      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: opacity * 0.8);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      // Draw small rectangles as confetti
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 8, height: 5),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Subtle grid background
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF9B515)
      ..strokeWidth = 1;

    const step = 40.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
