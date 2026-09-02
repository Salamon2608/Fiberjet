import 'package:flutter/material.dart';
import 'package:fiberjet/services/admin_data_service.dart';
import 'package:fiberjet/screens/admin/user_profile_screen.dart';

class TechnicianManagementScreen extends StatefulWidget {
  const TechnicianManagementScreen({super.key});

  @override
  State<TechnicianManagementScreen> createState() => _TechnicianManagementScreenState();
}

class _TechnicianManagementScreenState extends State<TechnicianManagementScreen> {
  bool _isLoading = true;
  List<dynamic> _technicians = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTechnicians();
  }

  Future<void> _fetchTechnicians() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await AdminDataService.getTechnicians();

    setState(() {
      _isLoading = false;
      if (result.success) {
        _technicians = result.data['technicians'] ?? [];
      } else {
        _error = result.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF6366F1); // Indigo for Admin
    final surfaceColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Technicians Management', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _technicians.isEmpty
                  ? const Center(child: Text('No technicians found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _technicians.length,
                      itemBuilder: (context, index) {
                        final tech = _technicians[index];
                        return _buildTechCard(tech, isDarkMode, surfaceColor, primaryColor);
                      },
                    ),
    );
  }

  Widget _buildTechCard(Map<String, dynamic> tech, bool isDarkMode, Color surfaceColor, Color primaryColor) {
    final name = tech['name'] ?? 'Unknown';
    final email = tech['email'] ?? 'No email';
    
    final completedJobs = tech['completed_jobs'] ?? 0;
    final pendingJobs = tech['pending_jobs'] ?? 0;
    final resolvedComplaints = tech['resolved_complaints'] ?? 0;
    final activeComplaints = tech['active_complaints'] ?? 0;

    return GestureDetector(
      onTap: () {
        final Map<String, dynamic> userMap = Map.from(tech);
        userMap['role'] = 'technician';
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => UserProfileScreen(user: userMap),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange.withValues(alpha: 0.1),
                  child: const Icon(Icons.handyman, color: Colors.orange),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Jobs: $completedJobs Done, $pendingJobs Active', style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('Tickets: $resolvedComplaints Resolved, $activeComplaints Active', style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
