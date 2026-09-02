import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fiberjet/services/admin_data_service.dart';
import 'package:intl/intl.dart';

class LeadOversightScreen extends StatefulWidget {
  const LeadOversightScreen({super.key});

  @override
  State<LeadOversightScreen> createState() => _LeadOversightScreenState();
}

class _LeadOversightScreenState extends State<LeadOversightScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _leads = [];
  Map<String, int> _summary = {};

  late TabController _tabController;

  static const _stages = ['new', 'contacted', 'interested', 'negotiation', 'converted', 'lost'];
  static const Color _bgDark = Color(0xFF0F172A);
  static const Color _primary = Color(0xFFF9B515);
  static const Color _surfaceDark = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _stages.length + 1, vsync: this); // +1 for "All"
    _fetchLeads();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeads() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await AdminDataService.getGlobalLeads();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success) {
          _leads = res.data['leads'] ?? [];
          _summary = Map<String, int>.from(res.data['summary'] ?? {});
        } else {
          _error = res.message;
        }
      });
    }
  }

  List<dynamic> _getLeadsForTab(int index) {
    if (index == 0) return _leads;
    final stage = _stages[index - 1];
    return _leads.where((l) => l['stage'] == stage).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        title: const Text('Lead Oversight', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: _primary,
          labelColor: _primary,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(text: 'All (${_leads.length})'),
            ..._stages.map((s) => Tab(text: '${s.toUpperCase()} (${_summary[s] ?? 0})')),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : TabBarView(
                  controller: _tabController,
                  children: List.generate(_stages.length + 1, (index) {
                    final tabLeads = _getLeadsForTab(index);
                    if (tabLeads.isEmpty) {
                      return const Center(child: Text('No leads found.', style: TextStyle(color: Colors.white54)));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: tabLeads.length,
                      itemBuilder: (context, i) {
                        return _buildLeadCard(tabLeads[i]);
                      },
                    );
                  }),
                ),
    );
  }

  Widget _buildLeadCard(Map<String, dynamic> lead) {
    final stage = lead['stage'] ?? 'unknown';
    Color stageColor;
    switch (stage) {
      case 'new': stageColor = Colors.blue; break;
      case 'contacted': stageColor = Colors.orange; break;
      case 'interested': stageColor = Colors.purple; break;
      case 'negotiation': stageColor = Colors.amber; break;
      case 'converted': stageColor = Colors.green; break;
      case 'lost': stageColor = Colors.red; break;
      default: stageColor = Colors.grey;
    }

    final date = lead['created_at'] != null 
        ? DateFormat('MMM d, yyyy').format(DateTime.parse(lead['created_at']))
        : 'Unknown';

    return Card(
      color: _surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    lead['customer_name'] ?? 'Unknown',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stageColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: stageColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    stage.toUpperCase(),
                    style: GoogleFonts.inter(color: stageColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.phone, color: Colors.white54, size: 14),
                const SizedBox(width: 8),
                Text(lead['phone'] ?? 'N/A', style: const TextStyle(color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_pin_circle, color: Colors.white54, size: 14),
                const SizedBox(width: 8),
                Text('Rep: ${lead['sales_person_name'] ?? 'Unassigned'}', style: const TextStyle(color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white54, size: 14),
                const SizedBox(width: 8),
                Text('Created: $date', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
