import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fiberjet/services/tech_data_service.dart';

class TechNotificationsScreen extends StatefulWidget {
  const TechNotificationsScreen({super.key});

  @override
  State<TechNotificationsScreen> createState() => _TechNotificationsScreenState();
}

class _TechNotificationsScreenState extends State<TechNotificationsScreen> {
  static const Color _navy = Color(0xFF1E3A8A);

  bool _isLoading = true;
  List<dynamic> _notifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    final result = await TechDataService.getNotifications();
    if (result.success && result.data != null) {
      final data = result.data as Map<String, dynamic>;
      setState(() {
        _notifications = (data['notifications'] as List?) ?? [];
        _unreadCount = data['unread_count'] ?? 0;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    await TechDataService.markNotificationsRead();
    _fetch();
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'ticket': return Icons.confirmation_number;
      case 'job': return Icons.work;
      case 'alert': return Icons.warning;
      case 'system': return Icons.info;
      default: return Icons.notifications;
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'ticket': return Colors.orange;
      case 'job': return Colors.blue;
      case 'alert': return Colors.red;
      case 'system': return Colors.purple;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: Text('Notifications', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text('Mark all read', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : _notifications.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.notifications_off, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('No notifications', style: GoogleFonts.inter(color: Colors.grey, fontSize: 16)),
                ]))
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (ctx, i) {
                      final n = _notifications[i] as Map<String, dynamic>;
                      final title = n['title']?.toString() ?? 'Notification';
                      final body = n['body']?.toString() ?? '';
                      final type = n['type']?.toString();
                      final isRead = n['is_read'] == true;
                      final sentAt = n['sent_at']?.toString();
                      String timeText = '';
                      if (sentAt != null) {
                        final dt = DateTime.tryParse(sentAt);
                        if (dt != null) {
                          final diff = DateTime.now().difference(dt);
                          if (diff.inMinutes < 60) {
                            timeText = '${diff.inMinutes}m ago';
                          } else if (diff.inHours < 24) {
                            timeText = '${diff.inHours}h ago';
                          } else {
                            timeText = '${diff.inDays}d ago';
                          }
                        }
                      }
                      final color = _typeColor(type);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isRead ? Colors.white : color.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isRead ? Colors.grey.shade200 : color.withValues(alpha: 0.2)),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: Icon(_typeIcon(type), color: color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: isRead ? FontWeight.w500 : FontWeight.w700))),
                              Text(timeText, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                            ]),
                            if (body.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(body, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ])),
                          if (!isRead) ...[
                            const SizedBox(width: 8),
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          ],
                        ]),
                      );
                    },
                  ),
                ),
    );
  }
}
