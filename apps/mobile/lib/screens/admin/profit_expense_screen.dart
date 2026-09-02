import 'package:flutter/material.dart';
import 'package:fiberjet/services/admin_data_service.dart';

class ProfitExpenseScreen extends StatefulWidget {
  const ProfitExpenseScreen({super.key});

  @override
  State<ProfitExpenseScreen> createState() => _ProfitExpenseScreenState();
}

class _ProfitExpenseScreenState extends State<ProfitExpenseScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _financials = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchFinancials();
  }

  Future<void> _fetchFinancials() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await AdminDataService.getFinancials();

    setState(() {
      _isLoading = false;
      if (result.success) {
        _financials = result.data;
      } else {
        _error = result.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    final summary = _financials['summary'] as Map<String, dynamic>? ?? {};
    final revenue = (summary['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final expenses = (summary['total_expenses'] as num?)?.toDouble() ?? 0.0;
    final profit = (summary['net_profit'] as num?)?.toDouble() ?? (revenue - expenses);
    final bool isProfitable = profit >= 0;

    final revBreakdown = _financials['revenue_breakdown'] as Map<String, dynamic>? ?? {};
    final expBreakdown = _financials['expense_breakdown'] as Map<String, dynamic>? ?? {};
    final forecast = _financials['forecast'] as Map<String, dynamic>? ?? {};
    final revTrend = _financials['revenue_trend'] as List<dynamic>? ?? [];
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F172A) : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Profit & Expenses', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Net Profit Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isProfitable 
                                ? [Colors.green.shade500, Colors.green.shade800]
                                : [Colors.red.shade500, Colors.red.shade800],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: (isProfitable ? Colors.green : Colors.red).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text('NET PROFIT (YTD)', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            const SizedBox(height: 8),
                            Text(
                              '\$${profit.abs().toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                            ),
                            if (!isProfitable)
                              const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Text('(Loss)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Revenue & Expense Overview
                      Row(
                        children: [
                          Expanded(
                            child: _buildOverviewCard('Revenue', '\$${revenue.toStringAsFixed(2)}', Icons.arrow_upward, Colors.green, surfaceColor, textColor),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildOverviewCard('Expenses', '\$${expenses.toStringAsFixed(2)}', Icons.arrow_downward, Colors.red, surfaceColor, textColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Forecasting Section
                      _buildSectionHeader('Forecasting & Growth'),
                      const SizedBox(height: 12),
                      _buildForecastingCard(forecast, surfaceColor, textColor),

                      const SizedBox(height: 24),

                      // Trend Charts
                      if (revTrend.isNotEmpty) ...[
                        _buildSectionHeader('Monthly Revenue Trend'),
                        const SizedBox(height: 12),
                        _buildTrendChart(revTrend, surfaceColor, Colors.green),
                        const SizedBox(height: 24),
                      ],

                      // Breakdowns
                      _buildSectionHeader('Revenue Sources'),
                      const SizedBox(height: 12),
                      _buildBreakdownList(revBreakdown, surfaceColor, textColor, isRevenue: true),
                      
                      const SizedBox(height: 24),
                      _buildSectionHeader('Operational Expenses'),
                      const SizedBox(height: 12),
                      _buildBreakdownList(expBreakdown, surfaceColor, textColor, isRevenue: false),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildOverviewCard(String title, String amount, IconData icon, Color color, Color surfaceColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(amount, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildForecastingCard(Map<String, dynamic> forecast, Color surfaceColor, Color textColor) {
    final futureRev = (forecast['future_revenue'] as num?)?.toDouble() ?? 0.0;
    final expExp = (forecast['expected_expenses'] as num?)?.toDouble() ?? 0.0;
    final growth = (forecast['growth_estimation'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Expected Revenue', style: TextStyle(color: Colors.grey)),
              Text('\$${futureRev.toStringAsFixed(2)}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Expected Expenses', style: TextStyle(color: Colors.grey)),
              Text('\$${expExp.toStringAsFixed(2)}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Growth Estimation', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Icon(growth >= 0 ? Icons.trending_up : Icons.trending_down, color: growth >= 0 ? Colors.green : Colors.red, size: 18),
                  const SizedBox(width: 4),
                  Text('${growth.toStringAsFixed(1)}%', style: TextStyle(color: growth >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownList(Map<String, dynamic> items, Color surfaceColor, Color textColor, {required bool isRevenue}) {
    if (items.isEmpty) return const Text('No data available');
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: items.entries.map((e) {
          final value = (e.value as num).toDouble();
          final title = e.key.replaceAll('_', ' ').toUpperCase();
          return ListTile(
            leading: Icon(isRevenue ? Icons.attach_money : Icons.money_off, color: isRevenue ? Colors.green : Colors.red),
            title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
            trailing: Text('\$${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrendChart(List<dynamic> trendData, Color surfaceColor, Color barColor) {
    if (trendData.isEmpty) return const SizedBox();
    
    // Find max value to scale bars
    double maxVal = 0;
    for (var item in trendData) {
      final val = (item['revenue'] as num?)?.toDouble() ?? 0;
      if (val > maxVal) maxVal = val;
    }
    if (maxVal == 0) maxVal = 1;

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: trendData.map((item) {
          final val = (item['revenue'] as num?)?.toDouble() ?? 0;
          final month = item['month'] as String? ?? '';
          final shortMonth = month.length > 5 ? month.substring(5) : month;
          
          final heightFactor = val / maxVal;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('\$${(val/1000).toStringAsFixed(1)}k', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 4),
              Container(
                width: 30,
                height: 120 * heightFactor,
                decoration: BoxDecoration(
                  color: barColor.withOpacity(0.8),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ),
              const SizedBox(height: 8),
              Text(shortMonth, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          );
        }).toList(),
      ),
    );
  }
}
