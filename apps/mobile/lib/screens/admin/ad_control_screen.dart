import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fiberjet/services/admin_data_service.dart';
import 'package:fiberjet/services/api_service.dart';

class AdControlScreen extends StatefulWidget {
  const AdControlScreen({super.key});

  @override
  State<AdControlScreen> createState() => _AdControlScreenState();
}

class _AdControlScreenState extends State<AdControlScreen> {
  static const Color _bgDark = Color(0xFF0A2540);
  static const Color _primary = Color(0xFF1152D4);
  static const Color _accentYellow = Color(0xFFFDB813);

  bool _isLoading = true;
  List<dynamic> _ads = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAds();
  }

  Future<void> _fetchAds() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await AdminDataService.getAds();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success) {
          _ads = result.data['ads'] ?? [];
        } else {
          _error = result.message;
        }
      });
    }
  }

  Future<void> _toggleAdStatus(String adId, bool currentActive) async {
    final res = await AdminDataService.updateAd(adId, {'is_active': !currentActive});
    if (res.success) {
      _fetchAds();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: ${res.message}')),
        );
      }
    }
  }

  Future<void> _deleteAd(String adId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Ad?'),
        content: const Text('This action cannot be undone.'),
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
      final res = await AdminDataService.deleteAd(adId);
      if (res.success) {
        _fetchAds();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ad deleted successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: ${res.message}')),
          );
        }
      }
    }
  }

  Future<void> _showEditAdDialog(dynamic ad) async {
    final titleController = TextEditingController(text: ad['title']?.toString());
    final urlController = TextEditingController(text: ad['image_path']?.toString());
    bool isActive = ad['is_active'] == true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF151E32),
          title: Text('Edit Ad Campaign', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Campaign Title',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'Ad Title',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: urlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Image URL',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'Image URL or path',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Campaign Active Status', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: Text(
                    isActive ? 'Currently Live' : 'Currently Paused',
                    style: TextStyle(color: isActive ? Colors.greenAccent : Colors.white54, fontSize: 12),
                  ),
                  value: isActive,
                  activeThumbColor: _primary,
                  onChanged: (val) => setDialogState(() => isActive = val),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newTitle = titleController.text.trim();
                final newUrl = urlController.text.trim();

                if (newTitle.isEmpty) return;

                final updates = <String, dynamic>{
                  'title': newTitle,
                  'is_active': isActive,
                };
                if (newUrl.isNotEmpty) {
                  updates['image_path'] = newUrl;
                }

                final messenger = ScaffoldMessenger.of(ctx);
                Navigator.pop(ctx);

                final res = await AdminDataService.updateAd(ad['id'].toString(), updates);
                if (res.success) {
                  _fetchAds();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Campaign updated successfully')),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error: ${res.message}')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size.zero,
                backgroundColor: _primary,
              ),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateAdDialog() {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    XFile? selectedImage;
    Uint8List? selectedImageBytes;
    bool isUrlMode = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF151E32),
          title: Text('New Ad Campaign', style: GoogleFonts.inter(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ad Title',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => isUrlMode = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isUrlMode ? _primary : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(child: Text('URL', style: TextStyle(color: Colors.white))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => isUrlMode = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !isUrlMode ? _primary : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(child: Text('Upload', style: TextStyle(color: Colors.white))),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isUrlMode)
                  TextField(
                    controller: urlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Image URL',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  )
                else
                  Column(
                    children: [
                      if (selectedImageBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 120, maxWidth: 300),
                            child: Image.memory(selectedImageBytes!, fit: BoxFit.cover),
                          ),
                        ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final picker = ImagePicker();
                          final image = await picker.pickImage(source: ImageSource.gallery);
                          if (image != null) {
                            final bytes = await image.readAsBytes();
                            setDialogState(() {
                              selectedImage = image;
                              selectedImageBytes = bytes;
                            });
                          }
                        },
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Select Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                if (isUrlMode && urlController.text.trim().isEmpty) return;
                if (!isUrlMode && selectedImage == null) return;
                
                // Capture messenger BEFORE popping dialog
                final messenger = ScaffoldMessenger.of(ctx);
                Navigator.pop(ctx);
                final res = await AdminDataService.createAd(
                  title: titleController.text.trim(),
                  imageUrl: isUrlMode ? urlController.text.trim() : null,
                  imageBytes: !isUrlMode ? selectedImageBytes : null,
                  imageFileName: !isUrlMode ? selectedImage?.name : null,
                );
                if (res.success) {
                  _fetchAds();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Ad created successfully')),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error: ${res.message}')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size.zero,
                backgroundColor: _primary,
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _primary))
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
                      : RefreshIndicator(
                          onRefresh: _fetchAds,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPageTitle(),
                                _buildAddButton(),
                                const SizedBox(height: 24),
                                _buildAdList(),
                                const SizedBox(height: 32),
                                _buildQuickMetrics(),
                                const SizedBox(height: 32),
                              ],
                            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _bgDark.withValues(alpha: 0.9),
        border: Border(bottom: BorderSide(color: _primary.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _primary.withValues(alpha: 0.2)),
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fiber Jet',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                'ADMIN CONSOLE',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: _accentYellow,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_outlined,
              color: Colors.white70,
              size: 22,
            ),
          ),
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade700,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _accentYellow, width: 2),
              ),
              child: const Icon(Icons.person, color: Colors.white54, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageTitle() {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage Promotional Ads',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Control active marketing campaigns on user dashboards.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _showCreateAdDialog,
          icon: const Icon(Icons.add_circle_outline, size: 20),
          label: const Text('Add New Ad Campaign'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            elevation: 6,
            shadowColor: _primary.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  Widget _buildAdList() {
    final totalAds = _ads.length;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ACTIVE & SCHEDULED',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _primary.withValues(alpha: 0.6),
                letterSpacing: 1.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _accentYellow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _accentYellow.withValues(alpha: 0.2)),
              ),
              child: Text(
                '$totalAds TOTAL',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _accentYellow,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_ads.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _primary.withValues(alpha: 0.1)),
            ),
            child: Center(
              child: Text('No ad campaigns yet. Create one!',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white54)),
            ),
          )
        else
          ..._ads.map(
            (ad) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildAdCard(ad),
            ),
          ),
      ],
    );
  }

  Widget _buildAdCard(dynamic ad) {
    final title = ad['title']?.toString() ?? 'Untitled';
    final isActive = ad['is_active'] == true;
    final adId = ad['id']?.toString() ?? '';
    final startDate = ad['start_date']?.toString();
    // final endDate = ad['end_date']?.toString();

    String statusText;
    Color statusColor;
    if (isActive) {
      statusText = 'LIVE NOW';
      statusColor = Colors.green;
    } else if (startDate != null && DateTime.tryParse(startDate)?.isAfter(DateTime.now()) == true) {
      statusText = 'SCHEDULED';
      statusColor = _accentYellow;
    } else {
      statusText = 'PAUSED';
      statusColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: ad['image_path'] != null
                ? Image.network(
                    ad['image_path'].toString().startsWith('http')
                        ? ad['image_path']
                        : '${ApiService.baseUrl}${ad['image_path']}',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white.withValues(alpha: 0.2),
                      size: 24,
                    ),
                  )
                : Icon(
                    Icons.image_outlined,
                    color: Colors.white.withValues(alpha: isActive ? 0.4 : 0.2),
                    size: 24,
                  ),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Opacity(
              opacity: isActive ? 1.0 : 0.6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 13, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text(
                        startDate != null ? 'From: ${startDate.substring(0, 10)}' : 'No schedule',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Analytics Row
                  Row(
                    children: [
                      const Icon(Icons.visibility, size: 12, color: Colors.blueAccent),
                      const SizedBox(width: 4),
                      Text(
                        '${ad['impressions'] ?? 0}',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.touch_app, size: 12, color: Colors.greenAccent),
                      const SizedBox(width: 4),
                      Text(
                        '${ad['clicks'] ?? 0}',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'CTR: ${((ad['impressions'] ?? 0) > 0 ? ((ad['clicks'] ?? 0) / (ad['impressions'] ?? 1) * 100).toStringAsFixed(1) : "0.0")}%',
                          style: GoogleFonts.inter(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Toggle + Delete
          Column(
            children: [
              Switch(
                value: isActive,
                onChanged: (v) => _toggleAdStatus(adId, isActive),
                activeThumbColor: _primary,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.grey.shade700,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _showEditAdDialog(ad),
                    child: const Icon(Icons.edit_outlined, color: Colors.white70, size: 18),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _deleteAd(adId),
                    child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMetrics() {
    final activeCount = _ads.where((a) => a['is_active'] == true).length;
    final inactiveCount = _ads.length - activeCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Metrics',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                label: 'ACTIVE ADS',
                value: '$activeCount',
                subtitle: 'Currently running',
                subtitleColor: Colors.greenAccent,
                bgColor: _primary.withValues(alpha: 0.05),
                borderColor: _primary.withValues(alpha: 0.1),
                labelColor: _primary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                label: 'PAUSED / SCHEDULED',
                value: '$inactiveCount',
                subtitle: 'Not currently visible',
                subtitleColor: Colors.white38,
                bgColor: _accentYellow.withValues(alpha: 0.05),
                borderColor: _accentYellow.withValues(alpha: 0.1),
                labelColor: _accentYellow.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required String subtitle,
    required Color subtitleColor,
    required Color bgColor,
    required Color borderColor,
    required Color labelColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: labelColor,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: subtitleColor,
            ),
          ),
        ],
      ),
    );
  }
}
