import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/ui.dart';

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
  final _chatController = TextEditingController();
  final _chatScroll = ScrollController();
  final List<Map<String, String>> _chat = [
    {
      'role': 'assistant',
      'content':
          'Здравствуйте! Я AI-помощник Детского такси. Могу помочь с поездкой, оплатой, маршрутом или передать вопрос оператору.',
    },
  ];
  bool _aiTyping = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _loadRequests();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScroll.dispose();
    super.dispose();
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
          : '',
    );
    final text = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          sos
              ? 'Экстренная связь'
              : trip != null
              ? 'Помощь по поездке #${trip.id}'
              : 'Написать оператору',
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ваше сообщение…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    try {
      await SupportService.send(text, type: sos ? 'sos' : 'call_request');
      _loadRequests();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Отправлено оператору')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ApiClient.errorMessage(e))));
      }
    }
  }

  Future<void> _sendChat({bool escalate = false}) async {
    final text = _chatController.text.trim();
    if (text.isEmpty && !escalate) return;
    _chatController.clear();
    if (text.isNotEmpty) {
      setState(() => _chat.add({'role': 'user', 'content': text}));
      _scrollChat();
    }

    if (escalate) {
      final message = text.isEmpty
          ? 'Нужна помощь оператора в чате поддержки.'
          : text;
      try {
        await SupportService.send(message, type: 'call_request');
        await _loadRequests();
        setState(
          () => _chat.add({
            'role': 'assistant',
            'content': 'Передал оператору. Он увидит обращение и ответит вам.',
          }),
        );
      } catch (e) {
        setState(
          () => _chat.add({
            'role': 'assistant',
            'content': ApiClient.errorMessage(e),
          }),
        );
      }
      _scrollChat();
      return;
    }

    setState(() => _aiTyping = true);
    try {
      final reply = await SupportService.aiReply(text, history: _chat);
      setState(() => _chat.add({'role': 'assistant', 'content': reply}));
    } catch (e) {
      setState(
        () => _chat.add({
          'role': 'assistant',
          'content':
              'Не получилось ответить автоматически. Могу передать вопрос оператору.',
        }),
      );
    } finally {
      if (mounted) setState(() => _aiTyping = false);
      _scrollChat();
    }
  }

  void _scrollChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScroll.hasClients) return;
      _chatScroll.animateTo(
        _chatScroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
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
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: sel ? AppColors.onBrand : AppColors.muted,
                  ),
                ),
                if (badge > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.onBrand : AppColors.danger,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$badge',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: sel ? AppColors.brand : Colors.white,
                      ),
                    ),
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
      child: Row(
        children: [
          seg(0, 'Уведомления', badge: unread),
          seg(1, 'Поддержка'),
        ],
      ),
    );
  }

  // ── Notifications tab ─────────────────────────────────────────────
  Widget _notificationsTab() {
    if (_notesLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadNotes,
      child: _notes.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                SizedBox(height: 40),
                EmptyState(
                  icon: Icons.notifications_none,
                  title: 'Пока нет уведомлений',
                  subtitle: 'Здесь появятся статусы поездок вашего ребёнка.',
                ),
              ],
            )
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
    if (type.contains('on_way') || type.contains('arrived')) {
      return Icons.near_me;
    }
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
            color: unread
                ? AppColors.brand.withValues(alpha: 0.6)
                : AppColors.line,
          ),
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
              child: Icon(
                _noteIcon('${n['type']}'),
                color: AppColors.brand,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${n['title']}',
                    style: TextStyle(
                      fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  if ('${n['body'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${n['body']}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _time('${n['created_at']}'),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (unread)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Support tab (order-based, Yandex-style) ───────────────────────
  Widget _supportTab() {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadRequests();
            },
            child: ListView(
              controller: _chatScroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                _chatHeader(),
                const SizedBox(height: 14),
                ..._chat.map(_chatBubble),
                if (_aiTyping) _typingBubble(),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _quickChip('??? ???????', Icons.near_me),
                    _quickChip('???????? ? ???????', Icons.credit_card),
                    _quickChip(
                      '??????? ? ??????????',
                      Icons.support_agent,
                      escalate: true,
                    ),
                    _quickChip('SOS', Icons.sos, sos: true),
                  ],
                ),
                if (_requests.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sub('??????? ?????????'),
                  const SizedBox(height: 10),
                  ..._requests.take(3).map(_requestTile),
                ],
              ],
            ),
          ),
        ),
        _chatComposer(),
      ],
    );
  }

  Widget _chatHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.35)),
      ),
      child: const Row(
        children: [
          SoftIcon(Icons.support_agent_outlined, size: 48),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '????????? ?? ?????',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 3),
                Text(
                  '??????? ???????? AI, ??? ????????????? ????????? ?????????.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatBubble(Map<String, String> m) {
    final mine = m['role'] == 'user';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: mine ? AppColors.brand : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
          border: mine ? null : Border.all(color: AppColors.line),
        ),
        child: Text(
          m['content'] ?? '',
          style: TextStyle(
            color: mine ? AppColors.onBrand : AppColors.ink,
            height: 1.25,
            fontWeight: mine ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _typingBubble() {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Chip(
          avatar: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.brand,
            ),
          ),
          label: Text('AI ????????...'),
        ),
      ),
    );
  }

  Widget _quickChip(
    String label,
    IconData icon, {
    bool escalate = false,
    bool sos = false,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 17),
      label: Text(label),
      onPressed: () {
        if (sos) {
          _compose(sos: true);
          return;
        }
        if (escalate) {
          _sendChat(escalate: true);
          return;
        }
        _chatController.text = label;
        _sendChat();
      },
    );
  }

  Widget _chatComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chatController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendChat(),
                decoration: const InputDecoration(
                  hintText: '???????? ?????????...',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _aiTyping ? null : () => _sendChat(),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: AppColors.onBrand,
              ),
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sub(String t) => Text(
    t,
    style: const TextStyle(
      color: AppColors.muted,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    ),
  );

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
              color: (sos ? AppColors.danger : AppColors.brand).withValues(
                alpha: 0.16,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              sos ? Icons.sos : Icons.chat_bubble_outline,
              color: sos ? AppColors.danger : AppColors.brand,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r['message'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _fmt('${r['created_at']}'),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
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
            child: Text(
              '${r['status'] ?? ''}',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
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
      return DateFormat(
        'd MMM, HH:mm',
        'ru',
      ).format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return '';
    }
  }
}
