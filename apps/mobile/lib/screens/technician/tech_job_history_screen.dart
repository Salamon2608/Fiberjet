import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fiberjet/services/tech_data_service.dart';
import 'active_job_screen.dart';

class TechJobHistoryScreen extends StatefulWidget {
  const TechJobHistoryScreen({super.key});
  @override
  State<TechJobHistoryScreen> createState() => _TechJobHistoryScreenState();
}

class _TechJobHistoryScreenState extends State<TechJobHistoryScreen> with SingleTickerProviderStateMixin {
  static const Color _navy = Color(0xFF1E3A8A);
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _allJobs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetch();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    final result = await TechDataService.getJobs();
    if (result.success && result.data != null) {
      setState(() { _allJobs = (result.data as Map<String, dynamic>)['jobs'] ?? []; _isLoading = false; });
    } else { setState(() => _isLoading = false); }
  }

  List<dynamic> _filtered(int tab) {
    if (tab == 0) return _allJobs;
    if (tab == 1) return _allJobs.where((j) => (j as Map)['status'] == 'completed').toList();
    return _allJobs.where((j) {
      final s = (j as Map)['status']?.toString() ?? '';
      return s == 'rejected' || s == 'cancelled';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
            color: Colors.white,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Job History', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: _navy)),
              Text('${_allJobs.length} total jobs', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              TabBar(controller: _tabController, onTap: (_) => setState(() {}),
                labelColor: _navy, unselectedLabelColor: Colors.grey,
                indicatorColor: _navy, indicatorWeight: 3,
                labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: [
                  Tab(text: 'All (${_allJobs.length})'),
                  Tab(text: 'Completed (${_filtered(1).length})'),
                  Tab(text: 'Rejected (${_filtered(2).length})'),
                ]),
            ]),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _navy))
                : RefreshIndicator(onRefresh: _fetch, child: TabBarView(
                    controller: _tabController,
                    children: [_buildList(0), _buildList(1), _buildList(2)],
                  )),
          ),
        ]),
      ),
    );
  }

  Widget _buildList(int tab) {
    final jobs = _filtered(tab);
    if (jobs.isEmpty) return Center(child: Text('No jobs found', style: GoogleFonts.inter(color: Colors.grey)));
    return ListView.builder(
      padding: const EdgeInsets.all(16), itemCount: jobs.length,
      itemBuilder: (ctx, i) {
        final job = jobs[i] as Map<String, dynamic>;
        final type = job['type']?.toString() ?? 'Job';
        final status = job['status']?.toString() ?? '';
        final customerName = job['customer_name']?.toString() ?? 'Customer';
        final address = job['address']?.toString() ?? '';
        final scheduledAt = job['scheduled_at']?.toString();
        String dateText = '';
        if (scheduledAt != null) {
          final dt = DateTime.tryParse(scheduledAt);
          if (dt != null) dateText = '${dt.day}/${dt.month}/${dt.year}';
        }

        Color sc;
        IconData si;
        switch (status) {
          case 'completed': sc = Colors.green; si = Icons.check_circle; break;
          case 'rejected': sc = Colors.red; si = Icons.cancel; break;
          case 'in_progress': sc = Colors.blue; si = Icons.engineering; break;
          case 'en_route': sc = Colors.orange; si = Icons.directions_car; break;
          default: sc = Colors.grey; si = Icons.schedule;
        }

        return GestureDetector(
          onTap: () {
            final jobId = job['id']?.toString();
            if (jobId != null) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveJobScreen(jobId: jobId)));
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200)),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(si, color: sc, size: 22)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$type — $customerName', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                if (address.isNotEmpty) Text(address, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                if (dateText.isNotEmpty) Text(dateText, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(status.replaceAll('_', ' '), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: sc)),
              ),
            ]),
          ),
        );
      },
    );
  }
}
