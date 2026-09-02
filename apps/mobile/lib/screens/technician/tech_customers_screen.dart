import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fiberjet/services/tech_data_service.dart';
import 'tech_customer_detail_screen.dart';

class TechCustomersScreen extends StatefulWidget {
  const TechCustomersScreen({super.key});

  @override
  State<TechCustomersScreen> createState() => _TechCustomersScreenState();
}

class _TechCustomersScreenState extends State<TechCustomersScreen> {
  static const Color _navy = Color(0xFF1E3A8A);
  static const Color _gold = Color(0xFFFBBF24);

  bool _isLoading = true;
  List<dynamic> _customers = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomers({String? search}) async {
    setState(() => _isLoading = true);
    final result = await TechDataService.getCustomers(search: search);
    if (result.success && result.data != null) {
      setState(() {
        _customers = (result.data as Map<String, dynamic>)['customers'] ?? [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _fetchCustomers(search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null),
                color: _gold,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: _navy))
                    : _customers.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('No customers found', style: GoogleFonts.inter(color: Colors.grey, fontSize: 16)),
                          ]))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: _customers.length,
                            itemBuilder: (ctx, i) => _buildCustomerCard(_customers[i] as Map<String, dynamic>),
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
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _navy.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.people, color: _navy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('My Customers', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _navy)),
              Text('${_customers.length} assigned', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          if (val.isEmpty) _fetchCustomers();
        },
        onSubmitted: (val) => _fetchCustomers(search: val.trim().isNotEmpty ? val.trim() : null),
        style: GoogleFonts.inter(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by name or phone...',
          hintStyle: GoogleFonts.inter(color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () {
                  _searchController.clear();
                  _fetchCustomers();
                })
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> c) {
    final name = c['name']?.toString() ?? 'Customer';
    final phone = c['phone']?.toString() ?? '';
    final planName = c['plan_name']?.toString();
    final speedMbps = c['speed_mbps'];
    final connectionStatus = c['connection_status']?.toString() ?? 'offline';
    final isOnline = connectionStatus == 'online';
    final signal = c['signal_strength'] as int?;
    final expiryDate = c['expiry_date']?.toString();

    String signalText = 'N/A';
    Color signalColor = Colors.grey;
    if (signal != null) {
      if (signal > -30) { signalText = 'Excellent'; signalColor = Colors.green; }
      else if (signal > -50) { signalText = 'Very Good'; signalColor = Colors.blue; }
      else if (signal > -70) { signalText = 'Good'; signalColor = Colors.orange; }
      else { signalText = 'Weak'; signalColor = Colors.red; }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => TechCustomerDetailScreen(customerId: c['id'].toString(), customerName: name),
        )).then((_) => _fetchCustomers());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: _navy.withValues(alpha: 0.1),
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'C',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _navy)),
                    ),
                    Positioned(bottom: 0, right: 0, child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    )),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(phone, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(isOnline ? 'Online' : 'Offline',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: isOnline ? Colors.green : Colors.red)),
                  ),
                  if (signal != null) ...[
                    const SizedBox(height: 4),
                    Text('$signalText (${signal}dBm)', style: GoogleFonts.inter(fontSize: 9, color: signalColor, fontWeight: FontWeight.w500)),
                  ],
                ]),
              ],
            ),
            if (planName != null || expiryDate != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    if (planName != null) ...[
                      Icon(Icons.wifi, size: 14, color: _navy),
                      const SizedBox(width: 4),
                      Text('$planName${speedMbps != null ? ' • ${speedMbps}Mbps' : ''}',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700)),
                    ],
                    const Spacer(),
                    if (expiryDate != null) ...[
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('Exp: ${expiryDate.split('T')[0]}',
                          style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
