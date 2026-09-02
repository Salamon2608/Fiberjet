import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fiberjet/services/sales_data_service.dart';

class CommissionTrackerScreen extends StatefulWidget {
  const CommissionTrackerScreen({super.key});

  @override
  State<CommissionTrackerScreen> createState() => _CommissionTrackerScreenState();
}

class _CommissionTrackerScreenState extends State<CommissionTrackerScreen> {
  static const Color _primary = Color(0xFFF9B515);
  static const Color _bgDark = Color(0xFF181611);
  static const Color _cardDark = Color(0xFF27241B);
  static const Color _borderDark = Color(0xFF3A3427);

  bool _isLoading = true;
  List<dynamic> _commissions = [];
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _fetchCommissions();
  }

  Future<void> _fetchCommissions() async {
    setState(() => _isLoading = true);
    final result = await SalesDataService.getCommissions();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.data != null) {
          final data = result.data as Map<String, dynamic>;
          _commissions = (data['commissions'] as List?) ?? [];
          _stats = (data['stats'] as Map<String, dynamic>?) ?? {};
        }
      });
    }
  }

  Future<void> _requestPayout() async {
    final pendingAmount = double.tryParse(_stats['pending_amount']?.toString() ?? '0') ?? 0;
    if (pendingAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No withdrawable balance available'), backgroundColor: Colors.red),
      );
      return;
    }

    final upiController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Request Payout', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ₹${pendingAmount.toStringAsFixed(2)}', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: _primary)),
            const SizedBox(height: 16),
            TextField(
              controller: upiController,
              style: GoogleFonts.manrope(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter UPI ID (e.g. name@upi)',
                hintStyle: GoogleFonts.manrope(color: Colors.grey),
                filled: true,
                fillColor: _bgDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _borderDark)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _borderDark)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primary)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.manrope(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: _bgDark),
            child: Text('Confirm', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final upi = upiController.text.trim();
      if (upi.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a UPI ID'), backgroundColor: Colors.red),
        );
        return;
      }

      final result = await SalesDataService.requestPayout(amount: pendingAmount, upiId: upi);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.success ? 'Payout request submitted!' : result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
        if (result.success) _fetchCommissions();
      }
    }
    upiController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        foregroundColor: Colors.white,
        title: Text('Commission Tracker', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : RefreshIndicator(
              onRefresh: _fetchCommissions,
              color: _primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(children: [
                  _buildHeroCard(),
                  _buildPerformanceChart(),
                  _buildRecentCommissions(),
                ]),
              ),
            ),
    );
  }

  Widget _buildHeroCard() {
    final pendingAmount = double.tryParse(_stats['pending_amount']?.toString() ?? '0') ?? 0;
    final totalPaid = double.tryParse(_stats['total_paid']?.toString() ?? '0') ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderDark),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 16)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total Withdrawable', style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text('₹${pendingAmount.toStringAsFixed(2)}', style: GoogleFonts.manrope(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
            CircleAvatar(radius: 20, backgroundColor: _primary.withValues(alpha: 0.2), child: const Icon(Icons.account_balance_wallet, color: _primary)),
          ]),
          const SizedBox(height: 8),
          Text('Total Paid: ₹${totalPaid.toStringAsFixed(2)}', style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _requestPayout,
              icon: const Icon(Icons.payments),
              label: const Text('Request Payout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: _bgDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildPerformanceChart() {
    // Compute monthly aggregates from commissions
    final monthlyData = <String, double>{};
    final monthLabels = <String>[];

    for (final c in _commissions) {
      final commission = c as Map<String, dynamic>;
      try {
        final date = DateTime.parse(commission['created_at'].toString());
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        final amount = double.tryParse(commission['amount']?.toString() ?? '0') ?? 0;
        monthlyData[key] = (monthlyData[key] ?? 0) + amount;
      } catch (_) {}
    }

    // Get last 6 months
    final now = DateTime.now();
    final months = <String>[];
    final values = <double>[];
    final labels = <String>[];
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      months.add(key);
      values.add(monthlyData[key] ?? 0);
      labels.add(monthNames[d.month - 1]);
    }

    final maxVal = values.isEmpty ? 1.0 : (values.reduce((a, b) => a > b ? a : b));
    final totalMonthly = values.isNotEmpty ? values.last : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Performance Trends', style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
          Row(children: [
            Text('Last 6 Months', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w500, color: _primary)),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: _primary),
          ]),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: _borderDark)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('This Month', style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey)),
                Text('₹${totalMonthly.toStringAsFixed(0)}', style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              height: 130,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(values.length, (i) {
                final fraction = maxVal > 0 ? values[i] / maxVal : 0.0;
                final isMax = values[i] == maxVal && maxVal > 0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: fraction > 0 ? fraction.clamp(0.05, 1.0) : 0.05,
                            child: Container(decoration: BoxDecoration(
                              color: isMax ? _primary : _primary.withValues(alpha: (fraction * 0.8).clamp(0.2, 1.0)),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                              boxShadow: isMax ? [BoxShadow(color: _primary.withValues(alpha: 0.3), blurRadius: 10)] : null,
                            )),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(labels[i], style: GoogleFonts.manrope(fontSize: 9, fontWeight: isMax ? FontWeight.w700 : FontWeight.w500, color: isMax ? _primary : Colors.grey)),
                    ]),
                  ),
                );
              })),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildRecentCommissions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Recent Commissions', style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 14),
        if (_commissions.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: _borderDark)),
            child: Center(child: Text('No commissions yet', style: GoogleFonts.manrope(color: Colors.grey))),
          )
        else
          ...(_commissions.take(10).map((c) {
            final commission = c as Map<String, dynamic>;
            final id = commission['id']?.toString() ?? '';
            final idShort = id.length > 6 ? id.substring(0, 6).toUpperCase() : id;
            final customerName = commission['customer_name']?.toString() ?? '';
            final amount = double.tryParse(commission['amount']?.toString() ?? '0') ?? 0;
            final status = commission['status']?.toString() ?? 'pending';

            Color statusColor;
            switch (status) {
              case 'approved':
              case 'paid':
                statusColor = Colors.green;
                break;
              case 'pending':
                statusColor = Colors.amber;
                break;
              default:
                statusColor = Colors.grey;
            }

            String dateInfo = '';
            try {
              final dt = DateTime.parse(commission['created_at'].toString());
              dateInfo = '${dt.day}/${dt.month}/${dt.year}';
            } catch (_) {}

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _commissionTile(
                'FJ-$idShort',
                '$dateInfo${customerName.isNotEmpty ? ' • $customerName' : ''}',
                '+₹${amount.toStringAsFixed(2)}',
                status[0].toUpperCase() + status.substring(1),
                statusColor,
              ),
            );
          })),
      ]),
    );
  }

  Widget _commissionTile(String id, String info, String amount, String status, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: _borderDark)),
      child: Row(children: [
        CircleAvatar(radius: 20, backgroundColor: statusColor.withValues(alpha: 0.1), child: Icon(
          status == 'Approved' || status == 'Paid' ? Icons.check_circle : Icons.pending,
          color: statusColor, size: 22,
        )),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ID: $id', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 2),
          Text(info, style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(amount, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
            child: Text(status, style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor)),
          ),
        ]),
      ]),
    );
  }
}
