import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fiberjet/services/admin_data_service.dart';

class PayoutApprovalsScreen extends StatefulWidget {
  const PayoutApprovalsScreen({super.key});

  @override
  State<PayoutApprovalsScreen> createState() => _PayoutApprovalsScreenState();
}

class _PayoutApprovalsScreenState extends State<PayoutApprovalsScreen> {
  static const Color _bgDark = Color(0xFF0A0C10);
  static const Color _cardDark = Color(0xFF161B26);
  static const Color _primary = Color(0xFF1152D4);
  static const Color _accentYellow = Color(0xFFFBBF24);

  int _selectedFilter = 0;
  final _filters = ['All Roles', 'Sales', 'Technician'];

  bool _isLoading = true;
  List<dynamic> _payouts = [];
  Map<String, dynamic> _summary = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPayouts();
  }

  Future<void> _fetchPayouts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    String? role;
    if (_selectedFilter == 1) role = 'sales';
    if (_selectedFilter == 2) role = 'technician';

    final result = await AdminDataService.getPendingPayouts(role: role);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success) {
          _payouts = result.data['payouts'] ?? [];
          _summary = result.data['summary'] ?? {};
        } else {
          _error = result.message;
        }
      });
    }
  }

  Future<void> _handleApprove(String payoutId) async {
    final res = await AdminDataService.approvePayout(payoutId);
    if (res.success) {
      _fetchPayouts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payout approved successfully')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${res.message}')),
        );
      }
    }
  }

  Future<void> _handleReject(String payoutId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Payout?'),
        content: const Text('Are you sure you want to reject this payout request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(minimumSize: Size.zero, backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await AdminDataService.rejectPayout(payoutId);
      if (res.success) {
        _fetchPayouts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payout rejected')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${res.message}')),
          );
        }
      }
    }
  }

  Future<void> _handleBulkApprove() async {
    if (_payouts.isEmpty) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bulk Approve Payouts'),
        content: Text('Are you sure you want to approve all ${_payouts.length} pending payouts shown?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _primary),
            child: const Text('Approve All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ids = _payouts.map((p) => p['id'].toString()).toList();
      final res = await AdminDataService.bulkApprovePayouts(ids);
      if (res.success) {
        _fetchPayouts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully bulk approved ${ids.length} payouts')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bulk approval failed: ${res.message}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _primary))
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
                      : RefreshIndicator(
                          onRefresh: _fetchPayouts,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 80),
                            child: Column(
                              children: [
                                _buildSummaryStats(),
                                _buildFilters(),
                                const SizedBox(height: 8),
                                if (_payouts.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Center(
                                      child: Text('No pending payouts',
                                          style: GoogleFonts.inter(color: Colors.white54)),
                                    ),
                                  )
                                else
                                  ..._payouts.map((p) => _buildPayoutCard(p)),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _bgDark.withOpacity(0.8),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payout Approvals',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              Text('Fiber Jet Admin Panel',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined, color: Colors.white70, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStats() {
    final totalPending = _summary['total_pending'] ?? 0;
    final totalAmount = _summary['total_amount'] ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL PENDING',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white54,
                          letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text('₹${_formatAmount(totalAmount)}',
                      style: GoogleFonts.inter(
                          fontSize: 22, fontWeight: FontWeight.w700, color: _primary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet, size: 14, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text('Awaiting approval',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white38)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _accentYellow.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _accentYellow.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('REQUESTS',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white54,
                          letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text('$totalPending',
                      style: GoogleFonts.inter(
                          fontSize: 22, fontWeight: FontWeight.w700, color: _accentYellow)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 14, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text('Pending Action',
                          style: GoogleFonts.inter(
                              fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white38)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  _filters.length,
                  (i) {
                    final selected = _selectedFilter == i;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedFilter = i);
                        _fetchPayouts();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? _primary : _cardDark,
                          borderRadius: BorderRadius.circular(999),
                          border: selected ? null : Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        alignment: Alignment.center,
                        child: Text(_filters[i],
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: selected ? Colors.white : Colors.white54)),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (_payouts.isNotEmpty)
            ElevatedButton.icon(
              onPressed: _handleBulkApprove,
              icon: const Icon(Icons.done_all, size: 16),
              label: const Text('Bulk Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPayoutCard(dynamic payout) {
    final name = payout['user_name']?.toString() ?? 'Unknown';
    final role = (payout['role']?.toString() ?? 'staff').toUpperCase();
    final amount = payout['amount'];
    final upiId = payout['upi_id']?.toString();
    final bankAccount = payout['bank_account']?.toString();
    final payoutId = payout['id']?.toString() ?? '';
    final createdAt = payout['created_at']?.toString() ?? '';

    final paymentMethod = upiId != null && upiId.isNotEmpty
        ? 'UPI: $upiId'
        : bankAccount != null && bankAccount.isNotEmpty
            ? 'Bank: $bankAccount'
            : 'No payment info';
    final paymentIcon = upiId != null && upiId.isNotEmpty
        ? Icons.account_balance_wallet_outlined
        : Icons.account_balance_outlined;

    Color roleColor = role.contains('SALES') ? _primary : Colors.white54;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.grey.shade700,
                        child: Text(name.isNotEmpty ? name[0] : '?',
                            style: GoogleFonts.inter(
                                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: _cardDark, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                                const SizedBox(height: 2),
                                Text(role,
                                    style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: roleColor,
                                        letterSpacing: 0.5)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('₹${_formatAmount(amount)}',
                                    style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _accentYellow.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.history, size: 10, color: _accentYellow),
                                      const SizedBox(width: 3),
                                      Text('PENDING',
                                          style: GoogleFonts.inter(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w700,
                                              color: _accentYellow)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(paymentIcon, size: 14, color: Colors.white38),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(paymentMethod,
                                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.calendar_today, size: 14, color: Colors.white38),
                            const SizedBox(width: 4),
                            Text(
                              createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt,
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Fraud Flags Display
            if (payout['fraud_flags'] != null && (payout['fraud_flags'] as List).isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: Colors.redAccent.withOpacity(0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: (payout['fraud_flags'] as List).map<Widget>((flag) {
                    return Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(flag.toString(),
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            // Action buttons
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _handleReject(payoutId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                              right: BorderSide(color: Colors.white.withOpacity(0.06))),
                        ),
                        child: Center(
                          child: Text('Reject',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.redAccent)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _handleApprove(payoutId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: _primary,
                        child: Center(
                          child: Text('Approve Payout',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
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
    );
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0';
    final num val = amount is num ? amount : num.tryParse(amount.toString()) ?? 0;
    if (val >= 100000) {
      return '${(val / 100000).toStringAsFixed(1)}L';
    } else if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(1)}k';
    }
    return val.toStringAsFixed(0);
  }
}
