import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/services.dart';
import '../parent/messages_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await NotificationsService.list();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markAll() async {
    await NotificationsService.markAllRead();
    _load();
  }

  IconData _icon(String type) {
    if (type.contains('assigned')) return Icons.directions_car;
    if (type.contains('on_way') || type.contains('arrived')) return Icons.near_me;
    if (type.contains('picked') || type.contains('progress')) return Icons.child_care;
    if (type.contains('delivered') || type.contains('completed')) return Icons.check_circle;
    if (type.contains('cancel')) return Icons.cancel;
    return Icons.notifications;
  }

  String _time(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'только что';
      if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
      if (dt.day == now.day && diff.inHours < 24) {
        return 'сегодня, ${DateFormat('HH:mm').format(dt)}';
      }
      if (diff.inHours < 48) return 'вчера, ${DateFormat('HH:mm').format(dt)}';
      return DateFormat('d MMM, HH:mm', 'ru').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _items.any((n) => n['is_read'] != true);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAll,
              child: const Text('Прочитать все'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 140),
                      Center(
                        child: Column(children: [
                          Text('🔔', style: TextStyle(fontSize: 40)),
                          SizedBox(height: 8),
                          Text('Пока нет уведомлений',
                              style: TextStyle(color: AppColors.muted)),
                        ]),
                      ),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final n = _items[i];
                        final unread = n['is_read'] != true;
                        return Card(
                          color: unread ? AppColors.brandSoft : Colors.white,
                          child: ListTile(
                            onTap: () async {
                              if (unread) {
                                await NotificationsService.markRead(n['id']);
                                _load();
                              }
                            },
                            leading: CircleAvatar(
                              backgroundColor: unread
                                  ? AppColors.brand
                                  : AppColors.bg,
                              child: Icon(_icon('${n['type']}'),
                                  color: AppColors.ink, size: 20),
                            ),
                            title: Text('${n['title']}',
                                style: TextStyle(
                                    fontWeight: unread
                                        ? FontWeight.w800
                                        : FontWeight.w600)),
                            subtitle: Text('${n['body'] ?? ''}'),
                            trailing: Text(_time('${n['created_at']}'),
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 11)),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

/// Bell button with an unread badge; opens the notifications screen.
class NotificationBell extends StatefulWidget {
  final Color color;
  const NotificationBell({super.key, this.color = AppColors.ink});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final c = await NotificationsService.unreadCount();
    if (mounted) setState(() => _unread = c);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: widget.color),
          onPressed: () async {
            // Notifications + support live together in the unified inbox.
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MessagesScreen()),
            );
            _refresh();
          },
        ),
        if (_unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                  color: AppColors.danger, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                _unread > 9 ? '9+' : '$_unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}
