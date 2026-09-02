import 'package:flutter/material.dart';
import 'package:fiberjet/services/admin_data_service.dart';
import 'package:fiberjet/screens/admin/user_profile_screen.dart';

class SalesManagementScreen extends StatefulWidget {
  const SalesManagementScreen({super.key});

  @override
  State<SalesManagementScreen> createState() => _SalesManagementScreenState();
}

class _SalesManagementScreenState extends State<SalesManagementScreen> {
  bool _isLoading = true;
  List<dynamic> _salesPersons = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSalesPersons();
  }

  Future<void> _fetchSalesPersons() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await AdminDataService.getSalesPersons();

    setState(() {
      _isLoading = false;
      if (result.success) {
        _salesPersons = result.data['sales_persons'] ?? [];
      } else {
        _error = result.message;
      }
    });
  }

  Future<void> _approveSales(String id, String action) async {
    final result = await AdminDataService.approveSalesPerson(id, action);
    if (result.success) {
      _fetchSalesPersons();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${result.message}')));
    }
  }

  Future<void> _toggleBlock(String id, bool isCurrentlyBlocked) async {
    final action = isCurrentlyBlocked ? 'Unblock' : 'Suspend';
    final TextEditingController reasonController = TextEditingController();
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action Sales Person?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to $action this sales representative?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Enter reason (e.g. Inactivity, Violations)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              minimumSize: Size.zero,
              backgroundColor: isCurrentlyBlocked ? Colors.green : Colors.red,
            ),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await AdminDataService.toggleUserBlock(
        id, 
        reason: reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null
      );
      if (result.success) {
        _fetchSalesPersons();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: ${result.message}')));
      }
    }
  }

  Future<void> _viewDocuments(String id) async {
    final result = await AdminDataService.getSalesDocuments(id);
    if (!mounted) return;
    if (result.success) {
      final docs = result.data as Map<String, dynamic>;
      if (docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No documents uploaded.')));
        return;
      }
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('KYC Documents'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: docs.entries.map((e) => ListTile(
              leading: const Icon(Icons.file_present),
              title: Text(e.key),
              subtitle: Text(e.value.toString()),
            )).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${result.message}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF6366F1); // Indigo for Admin
    final surfaceColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Team Management', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _salesPersons.isEmpty
                  ? const Center(child: Text('No sales persons found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _salesPersons.length,
                      itemBuilder: (context, index) {
                        final person = _salesPersons[index];
                        return _buildSalesCard(person, isDarkMode, surfaceColor, primaryColor);
                      },
                    ),
    );
  }

  Widget _buildSalesCard(Map<String, dynamic> person, bool isDarkMode, Color surfaceColor, Color primaryColor) {
    final status = person['status'] ?? 'pending';
    final name = person['name'] ?? 'Unknown';
    final email = person['email'] ?? 'No email';
    final isPending = status == 'pending';

    Color statusColor;
    if (status == 'active') statusColor = Colors.green;
    else if (status == 'blocked') statusColor = Colors.red;
    else statusColor = Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              final Map<String, dynamic> userMap = Map.from(person);
              userMap['role'] = 'sales';
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => UserProfileScreen(user: userMap),
              ));
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  child: Icon(Icons.support_agent, color: primaryColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isPending) ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _approveSales(person['id'], 'rejected'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveSales(person['id'], 'active'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ] else ...[
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Total Leads', person['total_leads']?.toString() ?? '0'),
                _buildStat('Converted', person['converted_leads']?.toString() ?? '0'),
                _buildStat('Commission', '\$${person['total_commission']?.toString() ?? '0'}'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewDocuments(person['id']),
                    icon: const Icon(Icons.description, size: 16),
                    label: const Text('Docs'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _toggleBlock(person['id'], status == 'blocked'),
                    icon: Icon(status == 'blocked' ? Icons.check_circle : Icons.block, size: 16),
                    label: Text(status == 'blocked' ? 'Unblock' : 'Suspend'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: status == 'blocked' ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
