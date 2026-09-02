import 'package:flutter/material.dart';
import 'package:fiberjet/services/admin_data_service.dart';
import 'package:fiberjet/screens/admin/user_profile_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _planController = TextEditingController();
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Active', 'Blocked', 'VIP'];

  bool _isLoading = true;
  List<dynamic> _users = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    String? status;
    bool? isVip;

    if (_selectedFilter == 'Active') status = 'active';
    if (_selectedFilter == 'Blocked') status = 'blocked';
    if (_selectedFilter == 'VIP') isVip = true;

    final result = await AdminDataService.getUsers(
      search: _searchController.text.isNotEmpty ? _searchController.text : null,
      planType: _planController.text.isNotEmpty ? _planController.text : null,
      status: status,
      isVip: isVip,
    );

    setState(() {
      _isLoading = false;
      if (result.success) {
        _users = result.data['users'] ?? [];
      } else {
        _error = result.message;
      }
    });
  }

  Future<void> _toggleBlockStatus(String userId, bool isBlocked) async {
    final action = isBlocked ? 'Unblock' : 'Block';
    final TextEditingController reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action User?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to $action this user?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Enter reason (e.g. Fraud, Unpaid)',
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
              backgroundColor: isBlocked ? Colors.green : Colors.red,
            ),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await AdminDataService.toggleUserBlock(
        userId, 
        reason: reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null
      );
      if (res.success) {
        _fetchUsers();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: ${res.message}')));
      }
    }
  }

  Future<void> _toggleVipStatus(String userId, bool isCurrentlyVip) async {
    final res = await AdminDataService.toggleVip(userId);
    if (res.success) {
      _fetchUsers();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update VIP status: ${res.message}')));
    }
  }

  Future<void> _deleteUser(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text('Are you sure you want to permanently delete "$userName"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              minimumSize: Size.zero,
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await AdminDataService.deleteUser(userId);
      if (res.success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted successfully')));
        _fetchUsers();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: ${res.message}')));
      }
    }
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final nameCtrl = TextEditingController(text: user['name']);
    final phoneCtrl = TextEditingController(text: user['phone']);
    final emailCtrl = TextEditingController(text: user['email'] ?? '');
    final passCtrl = TextEditingController();
    bool obscurePass = true;
    String selectedRole = user['role']?.toString() ?? 'customer';

    final roles = ['customer', 'sales', 'technician', 'admin'];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit User Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.mail_outline)),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: roles.contains(selectedRole) ? selectedRole : 'customer',
                  decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.badge_outlined)),
                  items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedRole = val);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passCtrl,
                  obscureText: obscurePass,
                  decoration: InputDecoration(
                    labelText: 'New Password (Leave blank to keep current)',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePass ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => obscurePass = !obscurePass),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final data = <String, dynamic>{};
                if (nameCtrl.text.trim() != user['name']) data['name'] = nameCtrl.text.trim();
                if (phoneCtrl.text.trim() != user['phone']) data['phone'] = phoneCtrl.text.trim();
                
                final finalEmail = emailCtrl.text.trim();
                final originalEmail = user['email'] ?? '';
                if (finalEmail != originalEmail) {
                  data['email'] = finalEmail.isNotEmpty ? finalEmail : null;
                }
                
                if (selectedRole != user['role']) data['role'] = selectedRole;
                if (passCtrl.text.isNotEmpty) data['password'] = passCtrl.text;

                if (data.isEmpty) {
                  Navigator.pop(ctx);
                  return;
                }

                Navigator.pop(ctx);
                final res = await AdminDataService.updateUser(user['id'], data);
                if (res.success) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User updated successfully')));
                  _fetchUsers();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: ${res.message}')));
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF6366F1); // Indigo for Admin
    final surfaceColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email or phone...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _fetchUsers();
                      },
                    ),
                    filled: true,
                    fillColor: surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _fetchUsers(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _planController,
                  decoration: InputDecoration(
                    hintText: 'Filter by Plan Name (e.g. Premium)',
                    prefixIcon: const Icon(Icons.wifi),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _planController.clear();
                        _fetchUsers();
                      },
                    ),
                    filled: true,
                    fillColor: surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _fetchUsers(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isSelected = filter == _selectedFilter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedFilter = filter);
                              _fetchUsers();
                            }
                          },
                          selectedColor: primaryColor.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: isSelected ? primaryColor : (isDarkMode ? Colors.white70 : Colors.black87),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // User List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : _users.isEmpty
                        ? const Center(child: Text('No users found.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              return _buildUserCard(user, isDarkMode, surfaceColor, primaryColor);
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _showAddUserDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _showAddUserDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'customer';
    bool isVip = false;

    final roles = ['customer', 'sales', 'technician'];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Create New User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
                const SizedBox(height: 8),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number')),
                const SizedBox(height: 8),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address')),
                const SizedBox(height: 8),
                TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedRole = val);
                  },
                ),
                if (selectedRole == 'customer') ...[
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Mark as VIP'),
                    value: isVip,
                    onChanged: (val) => setState(() => isVip = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty || passCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name, Phone, and Password are required')));
                  return;
                }
                Navigator.pop(ctx);
                final result = await AdminDataService.createUser({
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'email': emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                  'password': passCtrl.text,
                  'role': selectedRole,
                  'is_vip': isVip,
                });

                if (!mounted) return;
                if (result.success) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User created successfully')));
                  _fetchUsers();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${result.message}')));
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, bool isDarkMode, Color surfaceColor, Color primaryColor) {
    final isBlocked = user['status'] == 'blocked';
    final isVip = user['is_vip'] == true;
    final name = user['name'] ?? 'Unknown User';
    final email = user['email'] ?? 'No email';
    final phone = user['phone'] ?? 'No phone';

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => UserProfileScreen(user: user),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isBlocked ? Colors.red.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
        ),
        child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isBlocked ? Colors.red.withValues(alpha: 0.1) : primaryColor.withValues(alpha: 0.1),
                child: Icon(Icons.person, color: isBlocked ? Colors.red : primaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  decoration: isBlocked ? TextDecoration.lineThrough : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (user['active_plan'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    user['active_plan'],
                                    style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.w600),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isVip)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('VIP', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(phone, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: () => _toggleBlockStatus(user['id'], isBlocked),
                icon: Icon(isBlocked ? Icons.lock_open : Icons.block, size: 16, color: isBlocked ? Colors.green : Colors.red),
                label: Text(isBlocked ? 'Unblock' : 'Block', style: TextStyle(color: isBlocked ? Colors.green : Colors.red)),
              ),
              TextButton.icon(
                onPressed: () => _toggleVipStatus(user['id'], isVip),
                icon: Icon(isVip ? Icons.star_border : Icons.star, size: 16, color: Colors.amber),
                label: Text(isVip ? 'Remove VIP' : 'Make VIP', style: const TextStyle(color: Colors.amber)),
              ),
              TextButton.icon(
                onPressed: () => _editUser(user),
                icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF6366F1)),
                label: const Text('Edit', style: TextStyle(color: Color(0xFF6366F1))),
              ),
              TextButton.icon(
                onPressed: () => _deleteUser(user['id'], name),
                icon: const Icon(Icons.delete_outline, size: 16, color: Color.fromARGB(255, 211, 34, 34)),
                label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ],
      ),
    ));
  }
}
