import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/ui.dart';
import 'history_screen.dart';

/// Unified inbox: notifications + support in one place (two segments).
class MessagesScreen extends StatefulWidget {
  final int initialIndex;
  const MessagesScreen({super.key, this.initialIndex = 0});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late int _tab = widget.initialIndex;

  // Notifications
  List<Map<String, dynamic>> _notes = [];
  bool _notesLoading = true;
  // Support
  List _requests = [];
  List<Trip> _trips = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _loadRequests();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    try {
      _trips = await TripsService.list();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _loadNotes() async {
    setState(() => _notesLoading = true);
    try {
      _notes = await NotificationsService.list();
    } catch (_) {}
    if (mounted) setState(() => _notesLoading = false);
  }

  Future<void> _loadRequests() async {
    try {
      _requests = await SupportService.myRequests();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _compose({bool sos = false, Trip? trip}) async {
    final controller = TextEditingController(
        text: sos
            ? 'SOS! Нужна срочная помощь по поездке.'
            : trip != null
                ? 'Вопрос по поездке #${trip.id} (${trip.childName ?? ''}): '
                : '');
    final text = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(sos
            ? 'Экстренная связь'
            : trip != null
                ? 'Помощь по поездке #${trip.id}'
                : 'Написать оператору'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ваше сообщение…'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Отправить')),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    try {
      await SupportService.send(text, type: sos ? 'sos' : 'call_request');
      _loadRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Отправлено оператору')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiClient.errorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notes.where((n) => n['is_read'] != true).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Входящие'),
        actions: [
          if (_tab == 0 && unread > 0)
            TextButton(
              onPressed: () async {
                await NotificationsService.markAllRead();
                _loadNotes();
              },
              child: const Text('Прочитать все'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _segmented(unread),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [_notificationsTab(), _supportTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmented(int unread) {
    Widget seg(int i, String label, {int badge = 0}) {
      final sel = _tab == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? AppColors.brand : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: sel ? AppColors.onBrand : AppColors.muted)),
                if (badge > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                        color: sel ? AppColors.onBrand : AppColors.danger,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('$badge',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: sel ? AppColors.brand : Colors.white)),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        seg(0, 'Уведомления', badge: unread),
        seg(1, 'Поддержка'),
      ]),
    );
  }

  // ── Notifications tab ─────────────────────────────────────────────
  Widget _notificationsTab() {
    if (_notesLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    }
    return RefreshIndicator(
      onRefresh: _loadNotes,
      child: _notes.isEmpty
          ? ListView(padding: const EdgeInsets.all(16), children: const [
              SizedBox(height: 40),
              EmptyState(
                icon: Icons.notifications_none,
                title: 'Пока нет уведомлений',
                subtitle: 'Здесь появятся статусы поездок вашего ребёнка.',
              ),
            ])
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _notes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _noteTile(_notes[i]),
            ),
    );
  }

  IconData _noteIcon(String type) {
    if (type.contains('assigned')) return Icons.directions_car;
    if (type.contains('on_way') || type.contains('arrived')) return Icons.near_me;
    if (type.contains('picked') || type.contains('progress')) {
      return Icons.child_care;
    }
    if (type.contains('delivered') || type.contains('completed')) {
      return Icons.check_circle;
    }
    if (type.contains('cancel')) return Icons.cancel;
    return Icons.notifications;
  }

  Widget _noteTile(Map<String, dynamic> n) {
    final unread = n['is_read'] != true;
    return GestureDetector(
      onTap: () async {
        if (unread) {
          await NotificationsService.markRead(n['id']);
          _loadNotes();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: unread ? AppColors.brand.withValues(alpha: 0.6) : AppColors.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: unread ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_noteIcon('${n['type']}'),
                  color: AppColors.brand, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${n['title']}',
                      style: TextStyle(
                          fontWeight:
                              unread ? FontWeight.w800 : FontWeight.w600)),
                  if ('${n['body'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('${n['body']}',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 13)),
                  ],
                  const SizedBox(height: 4),
                  Text(_time('${n['created_at']}'),
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 11)),
                ],
              ),
            ),
            if (unread)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.brand, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  // ── Support tab (order-based, Yandex-style) ───────────────────────
  Widget _supportTab() {
    final recent = _trips.take(4).toList();
    return RefreshIndicator(
      onRefresh: () async {
        await _loadTrips();
        await _loadRequests();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('С какой поездкой помочь?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          _sub('Ваши поездки'),
          const SizedBox(height: 10),
          if (recent.isEmpty)
            const EmptyState(
              icon: Icons.local_taxi_outlined,
              title: 'Поездок пока нет',
              subtitle: 'Закажите поездку — здесь появится помощь по ней.',
            )
          else
            _group(recent.map(_tripHelpRow).toList()),
          const SizedBox(height: 10),
          _group([
            _plainRow(Icons.list_alt, 'Все поездки',
                onTap: () => _go(const HistoryScreen())),
          ]),
          const SizedBox(height: 22),
          _sub('Другое'),
          const SizedBox(height: 10),
          _group([
            _plainRow(Icons.support_agent, 'Написать оператору',
                trailingChat: true, onTap: () => _compose()),
            _plainRow(Icons.sos, 'Экстренная помощь (SOS)',
                danger: true, onTap: () => _compose(sos: true)),
          ]),
          if (_requests.isNotEmpty) ...[
            const SizedBox(height: 22),
            _sub('История обращений'),
            const SizedBox(height: 10),
            ..._requests.map(_requestTile),
          ],
        ],
      ),
    );
  }

  void _go(Widget s) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => s));

  Widget _sub(String t) => Text(t,
      style: const TextStyle(
          color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w700));

  Widget _group(List<Widget> children) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i != children.length - 1) {
        items.add(Padding(
          padding: const EdgeInsets.only(left: 62),
          child: Divider(height: 1, color: AppColors.line),
        ));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(children: items),
    );
  }

  Widget _tripHelpRow(Trip t) {
    final d = DateTime.tryParse(t.scheduledAt)?.toLocal();
    final when = d != null ? DateFormat('d MMM, HH:mm', 'ru').format(d) : '';
    final cancelled = t.status == 'cancelled';
    return ListTile(
      onTap: () => _compose(trip: t),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.local_taxi, color: AppColors.brand, size: 20),
      ),
      title: Text('Поездка · $when',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(
          cancelled ? 'Отменено' : '${t.priceAmount} ₸ · ${t.dropoffText}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: cancelled ? AppColors.danger : AppColors.muted,
              fontSize: 12)),
      trailing: Container(
        height: 36,
        width: 36,
        decoration:
            const BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
        child: const Icon(Icons.chat_bubble_outline,
            color: AppColors.brand, size: 18),
      ),
    );
  }

  Widget _plainRow(IconData icon, String title,
      {VoidCallback? onTap, bool trailingChat = false, bool danger = false}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
            color: (danger ? AppColors.danger : AppColors.brand)
                .withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(11)),
        child: Icon(icon,
            color: danger ? AppColors.danger : AppColors.brand, size: 20),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: danger ? AppColors.danger : AppColors.ink)),
      trailing: Icon(trailingChat ? Icons.chat_bubble_outline : Icons.chevron_right,
          color: AppColors.muted, size: trailingChat ? 20 : 24),
    );
  }

  Widget _requestTile(dynamic r) {
    final sos = r['type'] == 'sos';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: (sos ? AppColors.danger : AppColors.brand)
                  .withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(sos ? Icons.sos : Icons.chat_bubble_outline,
                color: sos ? AppColors.danger : AppColors.brand, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r['message'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(_fmt('${r['created_at']}'),
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${r['status'] ?? ''}',
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ),
        ],
      ),
    );
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

  String _fmt(String iso) {
    try {
      return DateFormat('d MMM, HH:mm', 'ru')
          .format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return '';
    }
  }
}
