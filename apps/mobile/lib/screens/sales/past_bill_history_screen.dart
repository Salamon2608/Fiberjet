import 'package:flutter/material.dart';
import 'package:fiberjet/services/sales_data_service.dart';

class PastBillHistoryScreen extends StatefulWidget {
  const PastBillHistoryScreen({super.key});

  @override
  State<PastBillHistoryScreen> createState() => _PastBillHistoryScreenState();
}

class _PastBillHistoryScreenState extends State<PastBillHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  List<dynamic> _bills = [];
  String? _selectedCustomerId;
  String? _error;

  Future<void> _fetchBills(String customerId) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _selectedCustomerId = customerId;
    });

    final result = await SalesDataService.getCustomerBills(customerId);

    setState(() {
      _isLoading = false;
      if (result.success) {
        _bills = result.data['bills'] ?? [];
      } else {
        _error = result.message;
        _bills = [];
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF00B0FF);
    final surfaceColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Bill History', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Customer ID Input / Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_search, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Enter Customer ID (e.g. CUST123)',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          _fetchBills(value);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.search, color: primaryColor),
                    onPressed: () {
                      if (_searchController.text.isNotEmpty) {
                        _fetchBills(_searchController.text);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Content Area
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                      : _selectedCustomerId == null
                          ? _buildEmptyState('Search for a customer to view their last 6 months of bills.', Icons.search)
                          : _bills.isEmpty
                              ? _buildEmptyState('No bills found for this customer.', Icons.receipt_long)
                              : _buildBillsList(isDarkMode, surfaceColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildBillsList(bool isDarkMode, Color surfaceColor) {
    return ListView.builder(
      itemCount: _bills.length,
      itemBuilder: (context, index) {
        final bill = _bills[index];
        final amount = bill['amount'] ?? 0;
        final status = bill['status'] ?? 'pending';
        final month = bill['month'] ?? 'Unknown Month';
        final isPaid = status == 'paid';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isPaid ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPaid ? Icons.check_circle : Icons.pending_actions,
                      color: isPaid ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        month,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: isPaid ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '\$$amount',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
        );
      },
    );
  }
}
