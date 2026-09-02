import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fiberjet/services/tech_data_service.dart';

class TechEarningsScreen extends StatefulWidget {
  const TechEarningsScreen({super.key});

  @override
  State<TechEarningsScreen> createState() => _TechEarningsScreenState();
}

class _TechEarningsScreenState extends State<TechEarningsScreen> {
  static const Color _primary = Color(0xFFF2CC0D);
  static const Color _navy = Color(0xFF1A2B4B);
  static const Color _navyLight = Color(0xFF2C436B);

  bool _isLoading = true;
  List<dynamic> _payouts = [];
  Map<String, dynamic> _stats = {};
  bool _isRequestingPayout = false;

  final _amountController = TextEditingController();
  final _bankController = TextEditingController();
  final _upiController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchEarnings();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _bankController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _fetchEarnings() async {
    setState(() => _isLoading = true);
    final result = await TechDataService.getEarnings();
    if (result.success && result.data != null) {
      final data = result.data as Map<String, dynamic>;
      setState(() {
        _payouts = (data['payouts'] as List?) ?? [];
        _stats = (data['stats'] as Map<String, dynamic>?) ?? {};
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestPayout() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter a valid amount'), backgroundColor: Colors.red,
      ));
      return;
    }
    if (_bankController.text.trim().isEmpty && _upiController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter bank account or UPI ID'), backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isRequestingPayout = true);
    final result = await TechDataService.requestPayout(
      amount: amount,
      bankAccount: _bankController.text.trim().isNotEmpty ? _bankController.text.trim() : null,
      upiId: _upiController.text.trim().isNotEmpty ? _upiController.text.trim() : null,
    );

    if (!mounted) return;
    setState(() => _isRequestingPayout = false);

    if (result.success) {
      _amountController.clear();
      _bankController.clear();
      _upiController.clear();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Payout request submitted!'), backgroundColor: Colors.green,
      ));
      _fetchEarnings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message), backgroundColor: Colors.red,
      ));
    }
  }

  void _showPayoutDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('Request Payout', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text('Amount (₹)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter amount...',
                prefixText: '₹ ',
                filled: true, fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Text('Bank Account (optional)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _bankController,
              decoration: InputDecoration(
                hintText: 'Account number...',
                filled: true, fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Text('UPI ID (optional)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _upiController,
              decoration: InputDecoration(
                hintText: 'e.g. name@upi',
                filled: true, fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isRequestingPayout ? null : _requestPayout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary, foregroundColor: _navy,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                child: _isRequestingPayout
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit Request'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: Text('Earnings & Payouts', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A2B4B)))
          : RefreshIndicator(
              onRefresh: _fetchEarnings,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(children: [
                  _buildBalanceCard(),
                  _buildStatsCard(),
                  _buildRecentPayouts(),
                ]),
              ),
            ),
    );
  }

  Widget _buildBalanceCard() {
    // Calculate total balance from pending + approved payouts
    double totalApproved = 0;
    double totalPending = 0;
    for (final p in _payouts) {
      final payout = p as Map<String, dynamic>;
      final amount = double.tryParse(payout['amount']?.toString() ?? '0') ?? 0;
      if (payout['status'] == 'approved') totalApproved += amount;
      if (payout['status'] == 'pending') totalPending += amount;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _navy,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: _navy.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Stack(children: [
          Positioned(right: -40, top: -40, child: Container(width: 160, height: 160, decoration: BoxDecoration(color: _navyLight, shape: BoxShape.circle))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total Earnings', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400)),
            const SizedBox(height: 4),
            Text('₹${totalApproved.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white)),
            if (totalPending > 0) ...[
              const SizedBox(height: 4),
              Text('₹${totalPending.toStringAsFixed(0)} pending', style: GoogleFonts.inter(fontSize: 13, color: _primary)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showPayoutDialog,
                icon: const Icon(Icons.payments, size: 18),
                label: const Text('Request Payout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary, foregroundColor: _navy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildStatsCard() {
    final totalJobs = _stats['total_jobs_30d'] ?? 0;
    final completedJobs = _stats['completed_jobs_30d'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Last 30 Days', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _statTile(Icons.work, Colors.blue, '$totalJobs', 'Total Jobs')),
            const SizedBox(width: 12),
            Expanded(child: _statTile(Icons.check_circle, Colors.green, '$completedJobs', 'Completed')),
            const SizedBox(width: 12),
            Expanded(child: _statTile(Icons.trending_up, _primary, '${_payouts.length}', 'Payouts')),
          ]),
        ]),
      ),
    );
  }

  Widget _statTile(IconData icon, Color color, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700)),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
      ]),
    );
  }

  Widget _buildRecentPayouts() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Recent Payouts', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
          Text('${_payouts.length} total', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey)),
        ]),
        const SizedBox(height: 12),
        if (_payouts.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
            child: Center(child: Text('No payouts yet', style: GoogleFonts.inter(color: Colors.grey))),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: _payouts.take(10).map((p) {
                final payout = p as Map<String, dynamic>;
                final amount = payout['amount']?.toString() ?? '0';
                final status = payout['status']?.toString() ?? 'pending';
                final createdAt = payout['created_at']?.toString();
                String timeText = '';
                if (createdAt != null) {
                  final dt = DateTime.tryParse(createdAt);
                  if (dt != null) {
                    timeText = '${dt.day}/${dt.month}/${dt.year}';
                  }
                }

                Color statusColor;
                switch (status) {
                  case 'approved':
                    statusColor = Colors.green;
                    break;
                  case 'rejected':
                    statusColor = Colors.red;
                    break;
                  default:
                    statusColor = Colors.amber;
                }

                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      CircleAvatar(radius: 20, backgroundColor: statusColor.withOpacity(0.1), child: Icon(
                        status == 'approved' ? Icons.check_circle : Icons.schedule,
                        color: statusColor, size: 20,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Payout Request', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                        Text(timeText, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('₹$amount', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text(status[0].toUpperCase() + status.substring(1), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor)),
                        ),
                      ]),
                    ]),
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                ]);
              }).toList(),
            ),
          ),
      ]),
    );
  }
}
