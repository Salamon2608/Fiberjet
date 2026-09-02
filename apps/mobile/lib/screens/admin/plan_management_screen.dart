import 'package:flutter/material.dart';
import 'package:fiberjet/services/admin_data_service.dart';

class PlanManagementScreen extends StatefulWidget {
  const PlanManagementScreen({super.key});
  @override
  State<PlanManagementScreen> createState() => _PlanManagementScreenState();
}

class _PlanManagementScreenState extends State<PlanManagementScreen> {
  static const Color _bg = Color(0xFF0F172A);
  static const Color _card = Color(0xFF1E293B);
  static const Color _primary = Color(0xFFF9B515);
  static const Color _navy = Color(0xFF1E3A8A);
  static const Color _green = Color(0xFF22C55E);
  static const Color _red = Color(0xFFEF4444);

  List<Map<String, dynamic>> _plans = [];
  List<String> _categories = [];
  String _selectedCategory = 'All';
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _loading = true);
    final res = await AdminDataService.getPlans(
      category: _selectedCategory == 'All' ? null : _selectedCategory,
      search: _searchQuery.isEmpty ? null : _searchQuery,
    );
    if (res.success && res.data != null) {
      setState(() {
        _plans = List<Map<String, dynamic>>.from(res.data['plans'] ?? []);
        _categories = ['All', ...List<String>.from(res.data['categories'] ?? [])];
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text('Plan Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPlans),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _showPlanForm(context),
        backgroundColor: _primary,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('New Plan', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search plans...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.4)),
                filled: true,
                fillColor: _card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (v) {
                _searchQuery = v;
                _loadPlans();
              },
            ),
          ),
          // Category chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final selected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(cat, style: TextStyle(color: selected ? Colors.black : Colors.white70, fontWeight: FontWeight.w600, fontSize: 12)),
                  selected: selected,
                  selectedColor: _primary,
                  backgroundColor: _card,
                  side: BorderSide.none,
                  onSelected: (_) { setState(() => _selectedCategory = cat); _loadPlans(); },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Plans list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _primary))
                : _plans.isEmpty
                    ? Center(child: Text('No plans found', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16)))
                    : RefreshIndicator(
                        onRefresh: _loadPlans,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: _plans.length,
                          itemBuilder: (_, i) => _buildPlanCard(_plans[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final isActive = plan['is_active'] == true;
    final badge = plan['badge'] as String?;
    final category = plan['category'] as String? ?? 'Popular';
    final ottBenefits = plan['ott_benefits'];
    final ottList = ottBenefits is Map ? ottBenefits.keys.toList() : <String>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? _navy.withValues(alpha: 0.3) : _red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: badge + category + actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF9F1C)]),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _navy.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(6)),
                  child: Text(category, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: isActive ? _green.withValues(alpha: 0.2) : _red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                  child: Text(isActive ? 'Active' : 'Inactive', style: TextStyle(color: isActive ? _green : _red, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white38, size: 20),
                  color: const Color(0xFF2D3748),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white))),
                    PopupMenuItem(value: 'toggle', child: Text(isActive ? 'Deactivate' : 'Activate', style: const TextStyle(color: Colors.white))),
                  ],
                  onSelected: (v) {
                    if (v == 'edit') _showPlanForm(context, plan: plan);
                    if (v == 'toggle') _togglePlan(plan);
                  },
                ),
              ],
            ),
          ),
          // Plan name + price
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: Text(plan['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                Text('₹${plan['price']}', style: const TextStyle(color: _primary, fontSize: 22, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          if (plan['description'] != null && (plan['description'] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(plan['description'], style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          const SizedBox(height: 10),
          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _statChip(Icons.speed, '${plan['speed_mbps']} Mbps'),
                const SizedBox(width: 8),
                _statChip(Icons.calendar_today, '${plan['validity_days'] ?? 30}d'),
                const SizedBox(width: 8),
                if (plan['data_per_day_gb'] != null)
                  _statChip(Icons.data_usage, '${plan['data_per_day_gb']}GB/day')
                else if (plan['data_limit_gb'] != null)
                  _statChip(Icons.data_usage, '${plan['data_limit_gb']}GB'),
                if (plan['fup_speed_mbps'] != null) ...[
                  const SizedBox(width: 8),
                  _statChip(Icons.trending_down, 'FUP ${plan['fup_speed_mbps']}Mbps'),
                ],
              ],
            ),
          ),
          // OTT badges
          if (ottList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: ottList.map((ott) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: Text(ott.toString(), style: const TextStyle(color: Color(0xFFA78BFA), fontSize: 10, fontWeight: FontWeight.w600)),
                )).toList(),
              ),
            ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _primary),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _togglePlan(Map<String, dynamic> plan) async {
    final isActive = plan['is_active'] == true;
    if (isActive) {
      await AdminDataService.deletePlan(plan['id']);
    } else {
      await AdminDataService.updatePlan(plan['id'], {'is_active': true});
    }
    _loadPlans();
  }

  void _showPlanForm(BuildContext context, {Map<String, dynamic>? plan}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _PlanFormScreen(plan: plan, onSaved: _loadPlans)));
  }
}

// ═══════════════════════════════════════════════════════════
//  Plan Create / Edit Form
// ═══════════════════════════════════════════════════════════
class _PlanFormScreen extends StatefulWidget {
  final Map<String, dynamic>? plan;
  final VoidCallback onSaved;
  const _PlanFormScreen({this.plan, required this.onSaved});
  @override
  State<_PlanFormScreen> createState() => _PlanFormScreenState();
}

class _PlanFormScreenState extends State<_PlanFormScreen> {
  static const Color _bg = Color(0xFF0F172A);
  static const Color _card = Color(0xFF1E293B);
  static const Color _primary = Color(0xFFF9B515);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _speed;
  late final TextEditingController _price;
  late final TextEditingController _validity;
  late final TextEditingController _dataLimit;
  late final TextEditingController _dataPerDay;
  late final TextEditingController _fupSpeed;
  late final TextEditingController _cloudStorage;
  late final TextEditingController _priority;

  String _category = 'Popular';
  String? _badge;
  bool _isActive = true;
  List<String> _selectedOtt = [];
  bool _saving = false;
  bool get _isEdit => widget.plan != null;

  static const List<String> _badgeOptions = ['Bestseller', 'Trending', 'Recommended', 'New', 'Value', 'Premium'];
  List<String> _categoryOptions = [];
  List<String> _ottPlatforms = [];
  bool _loadingMeta = true;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _name = TextEditingController(text: p?['name'] ?? '');
    _desc = TextEditingController(text: p?['description'] ?? '');
    _speed = TextEditingController(text: '${p?['speed_mbps'] ?? ''}');
    _price = TextEditingController(text: '${p?['price'] ?? ''}');
    _validity = TextEditingController(text: '${p?['validity_days'] ?? 30}');
    _dataLimit = TextEditingController(text: p?['data_limit_gb'] != null ? '${p!['data_limit_gb']}' : '');
    _dataPerDay = TextEditingController(text: p?['data_per_day_gb'] != null ? '${p!['data_per_day_gb']}' : '');
    _fupSpeed = TextEditingController(text: p?['fup_speed_mbps'] != null ? '${p!['fup_speed_mbps']}' : '');
    _cloudStorage = TextEditingController(text: '${p?['cloud_storage_gb'] ?? 0}');
    _priority = TextEditingController(text: '${p?['priority'] ?? 100}');
    _category = p?['category'] ?? 'Popular';
    _badge = p?['badge'];
    _isActive = p?['is_active'] ?? true;
    final ott = p?['ott_benefits'];
    if (ott is Map) _selectedOtt = ott.keys.map((e) => e.toString()).toList();
    _loadMetaData();
  }

  Future<void> _loadMetaData() async {
    final catRes = await AdminDataService.getCategories();
    final ottRes = await AdminDataService.getOttPlatforms();
    if (mounted) {
      setState(() {
        if (catRes.success && catRes.data != null) {
          _categoryOptions = List<Map<String, dynamic>>.from(catRes.data['categories'] ?? [])
              .map((c) => c['name'].toString()).toList();
        }
        if (_categoryOptions.isEmpty) _categoryOptions = ['Popular'];
        if (!_categoryOptions.contains(_category)) _category = _categoryOptions.first;
        if (ottRes.success && ottRes.data != null) {
          _ottPlatforms = List<Map<String, dynamic>>.from(ottRes.data['ott_platforms'] ?? [])
              .map((o) => o['name'].toString()).toList();
        }
        _loadingMeta = false;
      });
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _card,
      title: const Text('New Category', style: TextStyle(color: Colors.white)),
      content: TextField(controller: ctrl, style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(hintText: 'Category name', hintStyle: TextStyle(color: Colors.white38),
          filled: true, fillColor: _bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), style: ElevatedButton.styleFrom(backgroundColor: _primary),
          child: const Text('Add', style: TextStyle(color: Colors.black))),
      ],
    ));
    if (name != null && name.isNotEmpty) {
      final res = await AdminDataService.createCategory({'name': name});
      if (res.success) { await _loadMetaData(); setState(() => _category = name); }
    }
  }

  Future<void> _showAddOttDialog() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _card,
      title: const Text('New OTT Platform', style: TextStyle(color: Colors.white)),
      content: TextField(controller: ctrl, style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(hintText: 'Platform name', hintStyle: TextStyle(color: Colors.white38),
          filled: true, fillColor: _bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), style: ElevatedButton.styleFrom(backgroundColor: _primary),
          child: const Text('Add', style: TextStyle(color: Colors.black))),
      ],
    ));
    if (name != null && name.isNotEmpty) {
      final res = await AdminDataService.createOttPlatform({'name': name});
      if (res.success) { await _loadMetaData(); setState(() => _selectedOtt.add(name)); }
    }
  }

  @override
  void dispose() {
    _name.dispose(); _desc.dispose(); _speed.dispose(); _price.dispose();
    _validity.dispose(); _dataLimit.dispose(); _dataPerDay.dispose();
    _fupSpeed.dispose(); _cloudStorage.dispose(); _priority.dispose();
    super.dispose();
  }

  InputDecoration _inputDec(String label, {IconData? icon}) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
    prefixIcon: icon != null ? Icon(icon, color: _primary, size: 20) : null,
    filled: true,
    fillColor: _card,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg, elevation: 0,
        title: Text(_isEdit ? 'Edit Plan' : 'Create Plan', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─ Basic Info ─
            _sectionTitle('Basic Information'),
            const SizedBox(height: 8),
            TextFormField(controller: _name, style: const TextStyle(color: Colors.white), decoration: _inputDec('Plan Name *', icon: Icons.label), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _desc, style: const TextStyle(color: Colors.white), decoration: _inputDec('Description', icon: Icons.description), maxLines: 2),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _price, style: const TextStyle(color: Colors.white), decoration: _inputDec('Price (₹) *', icon: Icons.currency_rupee), keyboardType: TextInputType.number, validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _speed, style: const TextStyle(color: Colors.white), decoration: _inputDec('Speed (Mbps) *', icon: Icons.speed), keyboardType: TextInputType.number, validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _validity, style: const TextStyle(color: Colors.white), decoration: _inputDec('Validity (Days)', icon: Icons.calendar_today), keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _priority, style: const TextStyle(color: Colors.white), decoration: _inputDec('Priority', icon: Icons.sort), keyboardType: TextInputType.number)),
            ]),

            const SizedBox(height: 20),
            _sectionTitle('Data Limits'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextFormField(controller: _dataLimit, style: const TextStyle(color: Colors.white), decoration: _inputDec('Total Data (GB)', icon: Icons.data_usage), keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _dataPerDay, style: const TextStyle(color: Colors.white), decoration: _inputDec('Data/Day (GB)', icon: Icons.today), keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _fupSpeed, style: const TextStyle(color: Colors.white), decoration: _inputDec('FUP Speed (Mbps)', icon: Icons.trending_down), keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _cloudStorage, style: const TextStyle(color: Colors.white), decoration: _inputDec('Cloud (GB)', icon: Icons.cloud), keyboardType: TextInputType.number)),
            ]),

            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _sectionTitle('Category & Badge')),
              IconButton(icon: const Icon(Icons.add_circle_outline, color: _primary, size: 20), tooltip: 'Add Category', onPressed: _showAddCategoryDialog),
            ]),
            const SizedBox(height: 8),
            // Category dropdown
            _loadingMeta
                ? const LinearProgressIndicator(color: _primary)
                : DropdownButtonFormField<String>(
                    initialValue: _categoryOptions.contains(_category) ? _category : _categoryOptions.first,
                    dropdownColor: _card,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDec('Category', icon: Icons.category),
                    items: _categoryOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _category = v ?? _categoryOptions.first),
                  ),
            const SizedBox(height: 12),
            // Badge dropdown (nullable)
            DropdownButtonFormField<String>(
              initialValue: _badge,
              dropdownColor: _card,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDec('Badge (optional)', icon: Icons.star),
              items: [
                const DropdownMenuItem(value: null, child: Text('None', style: TextStyle(color: Colors.white54))),
                ..._badgeOptions.map((b) => DropdownMenuItem(value: b, child: Text(b))),
              ],
              onChanged: (v) => setState(() => _badge = v),
            ),

            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _sectionTitle('OTT Benefits')),
              IconButton(icon: const Icon(Icons.add_circle_outline, color: _primary, size: 20), tooltip: 'Add OTT Platform', onPressed: _showAddOttDialog),
            ]),
            const SizedBox(height: 8),
            _loadingMeta
                ? const LinearProgressIndicator(color: _primary)
                : Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _ottPlatforms.map((ott) {
                      final selected = _selectedOtt.contains(ott);
                      return FilterChip(
                        label: Text(ott, style: TextStyle(color: selected ? Colors.black : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                        selected: selected,
                        selectedColor: _primary,
                        backgroundColor: _card,
                        checkmarkColor: Colors.black,
                        side: BorderSide(color: selected ? _primary : Colors.white12),
                        onSelected: (v) => setState(() => v ? _selectedOtt.add(ott) : _selectedOtt.remove(ott)),
                      );
                    }).toList(),
                  ),

            const SizedBox(height: 20),
            // Active toggle
            SwitchListTile(
              title: const Text('Active', style: TextStyle(color: Colors.white)),
              value: _isActive,
              activeThumbColor: _primary,
              tileColor: _card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onChanged: (v) => setState(() => _isActive = v),
            ),

            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text(_isEdit ? 'Update Plan' : 'Create Plan', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final ottMap = <String, dynamic>{};
    for (final o in _selectedOtt) { ottMap[o] = true; }

    final data = <String, dynamic>{
      'name': _name.text.trim(),
      'description': _desc.text.trim(),
      'speed_mbps': int.tryParse(_speed.text) ?? 0,
      'price': double.tryParse(_price.text) ?? 0,
      'validity_days': int.tryParse(_validity.text) ?? 30,
      'is_active': _isActive,
      'category': _category,
      'badge': _badge,
      'priority': int.tryParse(_priority.text) ?? 100,
      'cloud_storage_gb': int.tryParse(_cloudStorage.text) ?? 0,
      'ott_benefits': ottMap.isNotEmpty ? ottMap : null,
    };

    if (_dataLimit.text.isNotEmpty) data['data_limit_gb'] = int.tryParse(_dataLimit.text);
    if (_dataPerDay.text.isNotEmpty) data['data_per_day_gb'] = double.tryParse(_dataPerDay.text);
    if (_fupSpeed.text.isNotEmpty) data['fup_speed_mbps'] = int.tryParse(_fupSpeed.text);

    final res = _isEdit
        ? await AdminDataService.updatePlan(widget.plan!['id'], data)
        : await AdminDataService.createPlan(data);

    setState(() => _saving = false);

    if (res.success && mounted) {
      widget.onSaved();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Plan updated!' : 'Plan created!'),
        backgroundColor: const Color(0xFF22C55E),
      ));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.message.isNotEmpty ? res.message : 'Something went wrong'),
        backgroundColor: const Color(0xFFEF4444),
      ));
    }
  }
}
