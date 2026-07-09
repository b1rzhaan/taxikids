import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/trip_status.dart';
import '../../widgets/ui.dart';
import '../shared/notifications_screen.dart';
import 'children_screen.dart';
import 'create_trip_screen.dart';
import 'history_screen.dart';
import 'messages_screen.dart';
import 'trip_tracking_screen.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  String _name = '';
  List<Child> _children = [];
  List<Trip> _trips = [];
  bool _loading = true;

  static const _terminal = {'completed', 'cancelled'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final me = await AuthService.me();
      _name = (me['full_name'] as String?)?.split(' ').first ?? '';
      _children = await ChildrenService.list();
      _trips = await TripsService.list();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 6) return 'Доброй ночи';
    if (h < 12) return 'Доброе утро';
    if (h < 18) return 'Добрый день';
    return 'Добрый вечер';
  }

  Future<void> _order() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateTripScreen()),
    );
    if (created != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final active = _trips.where((t) => !_terminal.contains(t.status)).toList();
    final today = _trips.where((t) {
      final d = DateTime.tryParse(t.scheduledAt)?.toLocal();
      final now = DateTime.now();
      return d != null &&
          d.year == now.year &&
          d.month == now.month &&
          d.day == now.day;
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.brand),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                  children: [
                    _entry(_header(), 0),
                    const SizedBox(height: 18),
                    _entry(_hero(activeCount: active.length), 1),
                    const SizedBox(height: 14),
                    _entry(_insightStrip(active.length, today.length), 2),
                    const SizedBox(height: 22),
                    if (active.isNotEmpty) ...[
                      _entry(const SectionHeader('Текущая поездка'), 3),
                      const SizedBox(height: 10),
                      _entry(_currentTrip(active.first), 4),
                      const SizedBox(height: 22),
                    ],
                    _entry(
                      SectionHeader(
                        'Мои дети',
                        action: 'Все',
                        onAction: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChildrenScreen(),
                            ),
                          );
                        },
                      ),
                      5,
                    ),
                    const SizedBox(height: 10),
                    _entry(_childrenRow(), 6),
                    const SizedBox(height: 22),
                    _entry(
                      SectionHeader(
                        'Сегодня',
                        action: 'История',
                        onAction: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HistoryScreen(),
                            ),
                          );
                        },
                      ),
                      7,
                    ),
                    const SizedBox(height: 10),
                    if (today.isEmpty)
                      _entry(_todayPlanEmpty(), 8)
                    else
                      ...today
                          .take(3)
                          .toList()
                          .asMap()
                          .entries
                          .map((e) => _entry(_todayTile(e.value), 8 + e.key)),
                    const SizedBox(height: 22),
                    _entry(_serviceCard(), 10),
                    const SizedBox(height: 22),
                    _entry(const SectionHeader('Быстрые действия'), 11),
                    const SizedBox(height: 10),
                    _entry(_quickActions(), 12),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        InitialAvatar(_name.isEmpty ? 'Р' : _name, radius: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              Text(
                _name.isEmpty ? 'С возвращением' : _name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const NotificationBell(),
      ],
    );
  }

  Widget _entry(Widget child, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index * 35),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// The centrepiece: a big yellow-accented "order a ride" card with the taxi.
  Widget _hero({required int activeCount}) {
    return GestureDetector(
      onTap: _order,
      child: Container(
        height: 262,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF4B8), Colors.white],
          ),
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand.withValues(alpha: 0.12),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              right: -18,
              bottom: 14,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(24 * (1 - value), 0),
                    child: Transform.scale(
                      scale: 0.94 + value * 0.06,
                      child: child,
                    ),
                  );
                },
                child: Image.asset(
                  'assets/car.png',
                  height: 112,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              right: 22,
              top: 26,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.brand.withValues(alpha: 0.25),
                    width: 9,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      activeCount > 0
                          ? 'Поездка в процессе'
                          : 'Готовы к заказу',
                      style: const TextStyle(
                        color: AppColors.onBrand,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                        width: 205,
                        child: Text(
                          'Закажите поездку\nдля ребёнка',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 22,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Маршрут, водитель и статус — в одном экране',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      const Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          TrustPill(
                            icon: Icons.location_on_outlined,
                            label: 'GPS',
                            color: Color(0xFF4C8DFF),
                          ),
                          TrustPill(
                            icon: Icons.verified_outlined,
                            label: 'Проверка',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 190,
                    height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              'Заказать',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.onBrand,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            color: AppColors.onBrand,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _childrenRow() {
    if (_children.isEmpty) {
      return _addChildPanel();
    }
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = _children[i];
          return Container(
            width: 200,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                InitialAvatar(c.fullName, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      if (c.school.isNotEmpty)
                        Text(
                          c.school,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _insightStrip(int activeCount, int todayCount) {
    final childrenCount = _children.length;
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            Icons.child_care_outlined,
            '$childrenCount',
            'детей',
            AppColors.brand,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metricCard(
            Icons.route_outlined,
            '$todayCount',
            'сегодня',
            const Color(0xFF4C8DFF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metricCard(
            Icons.shield_outlined,
            activeCount > 0 ? '$activeCount' : '24/7',
            activeCount > 0 ? 'активно' : 'связь',
            AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _metricCard(IconData icon, String value, String label, Color color) {
    return Container(
      height: 82,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addChildPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SoftIcon(
                Icons.child_care_outlined,
                bg: AppColors.brandSoft,
                size: 48,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Профиль ребёнка',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Нужен для быстрого заказа',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChildrenScreen()),
                  );
                  _load();
                },
                child: const Text('Добавить'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: _ChecklistItem(
                  icon: Icons.school_outlined,
                  label: 'Школа',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _ChecklistItem(
                  icon: Icons.home_work_outlined,
                  label: 'Адреса',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _ChecklistItem(
                  icon: Icons.notes_outlined,
                  label: 'Заметки',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _todayPlanEmpty() {
    return GestureDetector(
      onTap: _order,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const SoftIcon(Icons.alt_route_outlined, size: 48),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'День свободен',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Создайте маршрут за минуту',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    color: AppColors.onBrand,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _RoutePreview(),
          ],
        ),
      ),
    );
  }

  Widget _serviceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.22)),
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
                  'Оператор следит за поездкой',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text(
                  'Если маршрут изменится, статус появится в приложении.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _todayTile(Trip t) {
    final d = DateTime.tryParse(t.scheduledAt)?.toLocal();
    final time = d != null ? DateFormat('HH:mm').format(d) : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TripTrackingScreen(tripId: t.id)),
        ),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            time,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.brand,
            ),
          ),
        ),
        title: Text(
          t.childName ?? 'Поездка',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${t.pickupText} → ${t.dropoffText}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: StatusChip(t.status),
      ),
    );
  }

  Widget _currentTrip(Trip t) {
    final eta = (t.routeDurationS / 60).round();
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TripTrackingScreen(tripId: t.id)),
      ),
      child: PulseGlow(
        radius: 22,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.brand.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.brand,
                child: Icon(Icons.local_taxi, color: AppColors.onBrand),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.childName ?? 'Ребёнок',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusInfo(t.status).label,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '~$eta мин',
                  style: const TextStyle(
                    color: AppColors.onBrand,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickActions() {
    final items = [
      (Icons.add_location_alt_outlined, 'Заказать\nпоездку', _order),
      (
        Icons.event_note_outlined,
        'Календарь\nпоездок',
        () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HistoryScreen()),
          );
        },
      ),
      (
        Icons.child_care_outlined,
        'Мои\nдети',
        () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChildrenScreen()),
          );
        },
      ),
      (
        Icons.support_agent_outlined,
        'Помощь\n24/7',
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const MessagesScreen(initialIndex: 1),
            ),
          );
        },
      ),
    ];
    return Row(
      children: items.map((it) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: QuickActionTile(icon: it.$1, label: it.$2, onTap: it.$3),
          ),
        );
      }).toList(),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ChecklistItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.brand, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _RoutePreview extends StatelessWidget {
  const _RoutePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Column(
            children: [
              _routeDot(AppColors.brand),
              Container(width: 2, height: 26, color: AppColors.line),
              _routeDot(const Color(0xFFF97316)),
            ],
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Откуда забрать ребёнка',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                SizedBox(height: 12),
                Text(
                  'Куда отвезти',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }

  Widget _routeDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
