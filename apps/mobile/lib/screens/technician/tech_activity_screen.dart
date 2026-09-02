import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fiberjet/services/tech_data_service.dart';

class TechActivityScreen extends StatefulWidget {
  const TechActivityScreen({super.key});
  @override
  State<TechActivityScreen> createState() => _TechActivityScreenState();
}

class _TechActivityScreenState extends State<TechActivityScreen> {
  static const Color _navy = Color(0xFF1E3A8A);
  bool _isLoading = true;
  List<dynamic> _logs = [];

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    final result = await TechDataService.getActivityLog();
    if (result.success && result.data != null) {
      setState(() { _logs = (result.data as Map<String, dynamic>)['activity_logs'] ?? []; _isLoading = false; });
    } else { setState(() => _isLoading = false); }
  }

  IconData _icon(String a) {
    if (a.contains('reboot')) return Icons.restart_alt;
    if (a.contains('login')) return Icons.login;
    if (a.contains('reject')) return Icons.cancel;
    if (a.contains('resolve')) return Icons.check_circle;
    return Icons.history;
  }

  Color _color(String a) {
    if (a.contains('reboot')) return Colors.orange;
    if (a.contains('reject')) return Colors.red;
    if (a.contains('resolve') || a.contains('complete')) return Colors.green;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(backgroundColor: _navy, foregroundColor: Colors.white,
        title: Text('Activity Log', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700))),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: _navy))
          : _logs.isEmpty ? Center(child: Text('No activity yet', style: GoogleFonts.inter(color: Colors.grey)))
          : RefreshIndicator(onRefresh: _fetch, child: ListView.builder(
              padding: const EdgeInsets.all(16), itemCount: _logs.length,
              itemBuilder: (ctx, i) {
                final log = _logs[i] as Map<String, dynamic>;
                final action = log['action']?.toString() ?? '';
                final target = log['target_table']?.toString() ?? '';
                final dt = DateTime.tryParse(log['created_at']?.toString() ?? '');
                final time = dt != null ? '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}' : '';
                final c = _color(action);
                return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Column(children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: c.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(_icon(action), color: c, size: 18)),
                    if (i < _logs.length - 1) Expanded(child: Container(width: 2, color: Colors.grey.shade200)),
                  ]),
                  const SizedBox(width: 12),
                  Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 4),
                    Text(action.replaceAll('_', ' ').toUpperCase(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    if (target.isNotEmpty) Text('on $target', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                    Text(time, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                  ]))),
                ]));
              })),
    );
  }
}
