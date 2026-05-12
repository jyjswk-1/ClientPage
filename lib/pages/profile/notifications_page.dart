// 文件路径: lib/pages/profile/notifications_page.dart
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/local_db_service.dart';
import '../blog/blog_detail_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    // 先读本地（离线可用）
    final local = await LocalDbService.I.getLocalNotifications();
    if (mounted) setState(() { _notifications = local; _isLoading = false; });

    // 后台同步服务端（有网时补全）
    try {
      final remote = await ApiClient.instance.getNotifications();
      if (mounted) {
        setState(() => _notifications =
            remote.map((e) => Map<String, dynamic>.from(e as Map)).toList());
      }
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    await LocalDbService.I.markLocalNotificationRead();
    try { await ApiClient.instance.markNotificationRead(); } catch (_) {}
    _load();
  }

  Future<void> _markOneRead(int id) async {
    await LocalDbService.I.markLocalNotificationRead(id: id);
    try { await ApiClient.instance.markNotificationRead(id: id); } catch (_) {}
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'approve': return Icons.check_circle;
      case 'reject':  return Icons.cancel;
      case 'submit':  return Icons.upload_file;
      default:        return Icons.notifications;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'approve': return Colors.green;
      case 'reject':  return Colors.redAccent;
      case 'submit':  return Colors.blueAccent;
      default:        return Colors.orange;
    }
  }

  String _formatTime(dynamic raw) {
    if (raw == null) return '';
    // 本地存的是毫秒时间戳（int），服务端是 ISO 字符串
    if (raw is int) {
      final dt = DateTime.fromMillisecondsSinceEpoch(raw);
      return '${dt.month}-${dt.day} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    }
    final s = raw.toString();
    return s.length >= 16 ? s.replaceAll('T', ' ').substring(0, 16) : s;
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) {
      final v = n['is_read'];
      return v == 0 || v == false;
    }).length;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(unread > 0 ? '通知 ($unread 条未读)' : '通知'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          if (unread > 0)
            TextButton(onPressed: _markAllRead, child: const Text('全部已读')),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('暂无通知', style: TextStyle(color: Colors.grey[400])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final n      = Map<String, dynamic>.from(_notifications[index]);
                      final type   = (n['type'] as String?) ?? 'info';
                      final isRead = n['is_read'] == 1 || n['is_read'] == true;
                      final cid    = n['cid'] as int?;
                      final time   = _formatTime(n['created_at']);
                      final from   = (n['from_user'] as String?) ?? 'system';

                      return ListTile(
                        tileColor: isRead ? null : Colors.blueAccent.withValues(alpha: 0.04),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _colorFor(type).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_iconFor(type), color: _colorFor(type), size: 20),
                        ),
                        title: Text(
                          (n['title'] as String?) ?? '',
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          '$from · $time',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                        trailing: isRead ? null : Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                        ),
                        onTap: () async {
                          if (!isRead) {
                            final id = n['id'] as int?;
                            if (id != null) await _markOneRead(id);
                            setState(() => _notifications[index] = {...n, 'is_read': 1});
                          }
                          if (cid != null && mounted) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => BlogDetailPage(cid: cid),
                            ));
                          }
                        },
                      );
                    },
                  ),
                ),
    );
  }
}