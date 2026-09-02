import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:fiberjet/services/customer_data_service.dart';
import 'package:flutter_internet_speed_test/flutter_internet_speed_test.dart';
import 'package:intl/intl.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _needleController;
  late Animation<double> _needleAnimation;

  final internetSpeedTest = FlutterInternetSpeedTest();

  bool _isTesting = false;
  double _currentSpeed = 0;   // live speed during test
  double _gaugeValue = 0;     // 0.0–1.0 for gauge needle
  double _ping = 0;
  double _download = 0;
  double _upload = 0;
  double _jitter = 0;
  String _testStage = 'IDLE'; // IDLE, PING, DOWNLOAD, UPLOAD, DONE

  // History
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _averages;
  bool _loadingHistory = false;

  static const double _maxMbps = 200.0; // gauge max

  @override
  void initState() {
    super.initState();
    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _needleAnimation = CurvedAnimation(
      parent: _needleController,
      curve: Curves.easeInOutCubic,
    );
    _needleAnimation.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchHistory();
  }

  @override
  void dispose() {
    _needleController.dispose();
    super.dispose();
  }

  // ── animate needle to a target 0.0–1.0 value ──────────────
  void _animateGaugeTo(double targetValue) {
    final from = _gaugeValue;
    _needleController.reset();
    _needleAnimation = Tween<double>(begin: from, end: targetValue)
        .animate(CurvedAnimation(parent: _needleController, curve: Curves.easeInOutCubic))
      ..addListener(() {
        if (mounted) {
          setState(() {
            _gaugeValue = (_needleAnimation as Animation<double>).value;
          });
        }
      });
    _needleController.forward();
  }

  // ── Ping via stopwatch ─────────────────────────────────────
  Future<double> _measurePing() async {
    try {
      final w = Stopwatch()..start();
      await http.get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      w.stop();
      return w.elapsedMilliseconds.toDouble();
    } catch (_) {
      return 0;
    }
  }

  // ── Fetch history from backend ─────────────────────────────
  Future<void> _fetchHistory() async {
    if (mounted) setState(() => _loadingHistory = true);
    final result = await CustomerDataService.getSpeedTestHistory();
    if (mounted && result.success && result.data != null) {
      final data = result.data as Map<String, dynamic>;
      setState(() {
        _history = List<Map<String, dynamic>>.from(data['tests'] ?? []);
        _averages = data['averages'] as Map<String, dynamic>?;
        _loadingHistory = false;
      });
    } else {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  // ── Run the speed test ─────────────────────────────────────
  Future<void> _runTest() async {
    setState(() {
      _isTesting = true;
      _testStage = 'PING';
      _ping = 0;
      _download = 0;
      _upload = 0;
      _jitter = 0;
      _currentSpeed = 0;
    });
    _animateGaugeTo(0);

    // 1. Measure ping
    final pingMs = await _measurePing();
    if (mounted) setState(() => _ping = pingMs);

    // 2. Speed test via Fast.com
    await internetSpeedTest.startTesting(
      useFastApi: true,
      onStarted: () {
        if (mounted) setState(() => _testStage = 'DOWNLOAD');
      },
      onProgress: (double percent, TestResult data) {
        if (!mounted) return;
        final speed = data.transferRate;
        final stage = data.type == TestType.download ? 'DOWNLOAD' : 'UPLOAD';
        final target = (speed / _maxMbps).clamp(0.0, 1.0);

        setState(() {
          _testStage = stage;
          _currentSpeed = speed;
          if (data.type == TestType.download) {
            _download = speed;
          } else {
            _upload = speed;
          }
        });
        _animateGaugeTo(target);
      },
      onCompleted: (TestResult download, TestResult upload) async {
        if (!mounted) return;
        final dl = download.transferRate;
        final ul = upload.transferRate;

        setState(() {
          _download = dl;
          _upload = ul;
          _testStage = 'DONE';
          _isTesting = false;
          // Show download speed on gauge when done
          _currentSpeed = dl;
        });
        _animateGaugeTo((dl / _maxMbps).clamp(0.0, 1.0));

        // Save to backend then refresh history
        await CustomerDataService.saveSpeedTest(
          downloadMbps: dl,
          uploadMbps: ul,
          pingMs: _ping,
          jitterMs: _jitter,
        );
        await _fetchHistory();
      },
      onError: (String errorMessage, String speedTestError) {
        if (!mounted) return;
        setState(() {
          _isTesting = false;
          _testStage = 'IDLE';
        });
        _animateGaugeTo(0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test Error: $errorMessage'),
            backgroundColor: Colors.red[800],
            duration: const Duration(seconds: 5),
          ),
        );
      },
    );
  }

  // ── UI ────────────────────────────────────────────────────
  static const Color _primary = Color(0xFFFDC212);
  static const Color _bg = Color(0xFF0A1120);
  static const Color _surface = Color(0xFF131B2E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text(
          'SPEED TEST',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background gradient
          Positioned(
            top: 0, left: 0, right: 0, height: 350,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A233B), _bg],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildGauge(),
                  const SizedBox(height: 28),
                  _buildMetricRow(),
                  const SizedBox(height: 12),
                  _buildExtraStats(),
                  const SizedBox(height: 28),
                  _buildHistory(),
                ],
              ),
            ),
          ),
          // Bottom Button
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: _isTesting ? null : _runTest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: _bg,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  elevation: 8,
                  shadowColor: _primary.withValues(alpha: 0.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_isTesting ? Icons.hourglass_bottom : Icons.play_arrow_rounded),
                    const SizedBox(width: 8),
                    Text(
                      _isTesting
                          ? 'Testing... ($_testStage)'
                          : (_testStage == 'DONE' ? 'Test Again' : 'Start Test'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGauge() {
    // label at center
    String centerLabel;
    double centerValue;
    if (_testStage == 'IDLE') {
      centerLabel = 'TAP TO TEST';
      centerValue = 0;
    } else if (_testStage == 'PING') {
      centerLabel = 'PING';
      centerValue = 0;
    } else if (_testStage == 'DONE') {
      centerLabel = 'DOWNLOAD';
      centerValue = _download;
    } else {
      centerLabel = _testStage;
      centerValue = _currentSpeed;
    }

    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(260, 260),
            painter: _SpeedometerPainter(progress: _gaugeValue),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerLabel,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                centerValue.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 58,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -2,
                  height: 1,
                ),
              ),
              const Text(
                'MBPS',
                style: TextStyle(
                  color: _primary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          // Status pill
          Positioned(
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: _isTesting ? Colors.orange : Colors.greenAccent,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: _isTesting ? Colors.orange : Colors.green, blurRadius: 6)],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isTesting ? 'Testing $_testStage...' : 'Fiber Jet Network',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow() {
    return Row(
      children: [
        _metricCard('PING', _ping.toStringAsFixed(0), 'ms',
            Icons.network_check_rounded, Colors.white54),
        const SizedBox(width: 10),
        _metricCard('DOWN', _download.toStringAsFixed(1), 'Mbps',
            Icons.download_rounded, _primary,
            highlight: _testStage == 'DOWNLOAD'),
        const SizedBox(width: 10),
        _metricCard('UPLOAD', _upload.toStringAsFixed(1), 'Mbps',
            Icons.upload_rounded, const Color(0xFF4FC3F7),
            highlight: _testStage == 'UPLOAD'),
      ],
    );
  }

  Widget _metricCard(String label, String value, String unit,
      IconData icon, Color color, {bool highlight = false}) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: highlight ? color.withValues(alpha: 0.8) : Colors.white10,
            width: highlight ? 2 : 1,
          ),
          boxShadow: highlight
              ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 12)]
              : [],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: highlight ? color : Colors.white38, size: 14),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        color: highlight ? color : Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(unit, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildExtraStats() {
    return Row(
      children: [
        Expanded(child: _statRow(Icons.swap_horiz, 'Jitter', '${_jitter.toStringAsFixed(1)} ms')),
        const SizedBox(width: 24),
        Expanded(child: _statRow(Icons.signal_cellular_alt, 'Loss', '0%')),
      ],
    );
  }

  Widget _statRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white38, size: 14),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
          Text(value,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── History ───────────────────────────────────────────────
  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Test History',
                style: TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            if (!_loadingHistory)
              GestureDetector(
                onTap: _fetchHistory,
                child: const Icon(Icons.refresh_rounded, color: Colors.white38, size: 20),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Averages row (only when we have data)
        if (_averages != null && _history.isNotEmpty) _buildAveragesCard(),

        if (_loadingHistory)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(color: _primary),
          ))
        else if (_history.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10)),
            child: const Center(
              child: Text('No tests yet. Run your first speed test!',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                  textAlign: TextAlign.center),
            ),
          )
        else
          ..._history.take(10).map(_buildHistoryItem),
      ],
    );
  }

  Widget _buildAveragesCard() {
    final avgDl = (_averages!['download_mbps'] as num?)?.toDouble() ?? 0;
    final avgUl = (_averages!['upload_mbps'] as num?)?.toDouble() ?? 0;
    final avgPing = (_averages!['ping_ms'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2B4A), Color(0xFF0F1D33)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Average (last ${30} tests)',
              style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _avgStat('↓ Download', '${avgDl.toStringAsFixed(1)} Mbps', _primary),
              _avgStat('↑ Upload', '${avgUl.toStringAsFixed(1)} Mbps', const Color(0xFF4FC3F7)),
              _avgStat('⏱ Ping', '${avgPing.toStringAsFixed(0)} ms', Colors.white70),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avgStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> test) {
    final dl = (test['download_mbps'] as num?)?.toDouble() ?? 0;
    final ul = (test['upload_mbps'] as num?)?.toDouble() ?? 0;
    final ping = (test['ping_ms'] as num?)?.toDouble() ?? 0;
    final createdAt = test['created_at'];
    String timeLabel = '';
    if (createdAt != null) {
      try {
        final dt = createdAt is DateTime
            ? createdAt
            : DateTime.parse(createdAt.toString()).toLocal();
        timeLabel = DateFormat('MMM d, h:mm a').format(dt);
      } catch (_) {
        timeLabel = createdAt.toString();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.speed_rounded, color: _primary, size: 18),
          ),
          const SizedBox(width: 12),
          // Date
          Expanded(
            child: Text(timeLabel,
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ),
          // Down
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: [
              const Icon(Icons.download_rounded, color: _primary, size: 12),
              const SizedBox(width: 2),
              Text('${dl.toStringAsFixed(1)} Mbps',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.upload_rounded, color: Color(0xFF4FC3F7), size: 12),
              const SizedBox(width: 2),
              Text('${ul.toStringAsFixed(1)} Mbps',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ]),
          const SizedBox(width: 12),
          // Ping
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${ping.toStringAsFixed(0)} ms',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const Text('ping',
                style: TextStyle(color: Colors.white24, fontSize: 9)),
          ]),
        ],
      ),
    );
  }
}

// ── Speedometer Custom Painter ────────────────────────────────
class _SpeedometerPainter extends CustomPainter {
  final double progress; // 0.0 – 1.0

  const _SpeedometerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    // Track background
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepAngle, false,
      Paint()
        ..color = const Color(0xFF1E2D45)
        ..strokeWidth = 14
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      // Colored arc
      final gradient = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle * progress,
        colors: const [Color(0xFFFF6B00), Color(0xFFFDC212)],
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAngle * progress, false,
        Paint()
          ..shader = gradient.createShader(
              Rect.fromCircle(center: center, radius: radius))
          ..strokeWidth = 14
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );

      // Needle
      final angle = startAngle + sweepAngle * progress;
      final needleLength = radius - 30;
      final needlePaint = Paint()
        ..color = const Color(0xFFFDC212)
        ..style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + 4 * math.cos(angle + math.pi / 2),
            center.dy + 4 * math.sin(angle + math.pi / 2))
        ..lineTo(center.dx + needleLength * math.cos(angle),
            center.dy + needleLength * math.sin(angle))
        ..lineTo(center.dx + 4 * math.cos(angle - math.pi / 2),
            center.dy + 4 * math.sin(angle - math.pi / 2))
        ..close();
      canvas.drawPath(path, needlePaint);
    }

    // Center dot
    canvas.drawCircle(center, 8, Paint()..color = const Color(0xFF131B2E));
    canvas.drawCircle(center, 5, Paint()..color = const Color(0xFFFDC212));

    // Major tick marks at 0, 50, 100, 150, 200 Mbps positions
    final tickPaint = Paint()
      ..color = const Color(0xFF2A3B55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 5; i++) {
      final frac = i / 4.0;
      final angle = startAngle + sweepAngle * frac;
      final inner = radius - 8;
      final outer = radius + 4;
      canvas.drawLine(
        Offset(center.dx + inner * math.cos(angle),
            center.dy + inner * math.sin(angle)),
        Offset(center.dx + outer * math.cos(angle),
            center.dy + outer * math.sin(angle)),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_SpeedometerPainter old) => old.progress != progress;
}
