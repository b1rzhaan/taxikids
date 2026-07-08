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
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  children: [
                    _header(),
                    const SizedBox(height: 18),
                    _hero(),
                    const SizedBox(height: 24),
                    if (active.isNotEmpty) ...[
                      const SectionHeader('Текущая поездка'),
                      const SizedBox(height: 10),
                      _currentTrip(active.first),
                      const SizedBox(height: 24),
                    ],
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
                    const SizedBox(height: 10),
                    _childrenRow(),
                    const SizedBox(height: 24),
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
                    const SizedBox(height: 10),
                    if (today.isEmpty)
                      const EmptyState(
                        icon: Icons.event_available_outlined,
                        title: 'На сегодня поездок нет',
                        subtitle: 'Запланируйте поездку — она появится здесь.',
                      )
                    else
                      ...today.take(3).map(_todayTile),
                    const SizedBox(height: 24),
                    const SectionHeader('Быстрые действия'),
                    const SizedBox(height: 10),
                    _quickActions(),
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

  /// The centrepiece: a big yellow-accented "order a ride" card with the taxi.
  Widget _hero() {
    return GestureDetector(
      onTap: _order,
      child: Container(
        height: 196,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF282513), Color(0xFF16191F)],
          ),
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.35)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -6,
              bottom: 6,
              child: Image.asset(
                'assets/car.png',
                height: 116,
                fit: BoxFit.contain,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                        width: 210,
                        child: Text(
                          'Куда везём сегодня?',
                          style: TextStyle(
                            fontSize: 22,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Безопасно доставим ребёнка',
                        style: TextStyle(
                          color: AppColors.muted.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Заказать поездку',
                          style: TextStyle(
                            color: AppColors.onBrand,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward,
                          color: AppColors.onBrand,
                          size: 18,
                        ),
                      ],
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
      return EmptyState(
        icon: Icons.child_care_outlined,
        title: 'Добавьте ребёнка',
        subtitle: 'Укажите данные ребёнка, чтобы заказывать поездки.',
        actionLabel: '+ Добавить ребёнка',
        onAction: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChildrenScreen()),
          );
          _load();
        },
      );
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
