import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/ui.dart';
import '../parent/messages_screen.dart';
import '../shared/notifications_screen.dart';
import 'driver_earnings_screen.dart';
import 'driver_trip_screen.dart';
import 'driver_trips_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  Map<String, dynamic>? _me;
  List<Trip> _mine = [];
  int _availableCount = 0;
  bool _loading = true;
  bool _online = false;

  final _money = NumberFormat.decimalPattern('ru');
  static const _done = {'completed', 'cancelled'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _me = await DriverService.me();
      _online = _me?['is_available'] == true;
      _mine = (await TripsService.list())
          .where((t) => !_done.contains(t.status))
          .toList();
      _availableCount = (await TripsService.available()).length;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleOnline(bool v) async {
    setState(() => _online = v);
    try {
      _online = await DriverService.setOnline(v);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 6) return 'Доброй ночи';
    if (h < 12) return 'Доброе утро';
    if (h < 18) return 'Добрый день';
    return 'Добрый вечер';
  }

  @override
  Widget build(BuildContext context) {
    final name = (_me?['full_name'] as String?)?.split(' ').first ?? '';
    final stats = (_me?['stats'] as Map?) ?? {};
    final docStatus = '${_me?['doc_status'] ?? 'approved'}';
    final approved = docStatus == 'approved';
    Trip? next = _mine.isNotEmpty ? _mine.first : null;

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: [
                    Row(children: [
                      InitialAvatar(name.isEmpty ? 'В' : name, radius: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_greeting,
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 13)),
                            Text(name.isEmpty ? 'Водитель 👋' : '$name 👋',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      const NotificationBell(),
                    ]),
                    const SizedBox(height: 18),
                    if (!approved) ...[
                      _verificationBanner(docStatus),
                      const SizedBox(height: 12),
                    ],
                    _statusCard(approved),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: _stat('Сегодня заработали',
                              '${_money.format(stats['earned_today'] ?? 0)} ₸',
                              accent: true)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _stat(
                              'Поездок сегодня', '${stats['trips_today'] ?? 0}')),
                    ]),
                    const SizedBox(height: 12),
                    _balanceCard(stats),
                    const SizedBox(height: 24),
                    SectionHeader(next != null ? 'Следующая поездка' : 'Заказы'),
                    const SizedBox(height: 10),
                    if (next != null) _nextTrip(next) else _availableBanner(),
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

  /// Yellow banner shown while the driver's documents are being reviewed.
  Widget _verificationBanner(String status) {
    final rejected = status == 'rejected';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (rejected ? AppColors.danger : AppColors.brand)
            .withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: (rejected ? AppColors.danger : AppColors.brand)
                .withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        Icon(rejected ? Icons.error_outline : Icons.hourglass_top,
            color: rejected ? AppColors.danger : AppColors.brand, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rejected ? 'Заявка отклонена' : 'Аккаунт на проверке',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text(
                  rejected
                      ? 'Обратитесь в поддержку — документы не прошли проверку.'
                      : 'Оператор проверяет документы. Заказы станут доступны после одобрения.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
      ]),
    );
  }

  /// Big online/offline switch card — yellow-lit when the driver is on the line.
  Widget _statusCard(bool approved) {
    final on = _online && approved;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: on ? AppColors.brand : AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: on ? AppColors.brand : AppColors.line),
      ),
      child: Row(
        children: [
          Icon(on ? Icons.bolt : Icons.bedtime_outlined,
              color: on ? AppColors.onBrand : AppColors.muted, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    !approved
                        ? 'Недоступно'
                        : (on ? 'Вы на линии' : 'Вы не на линии'),
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: on ? AppColors.onBrand : AppColors.ink)),
                Text(
                    !approved
                        ? 'Дождитесь одобрения аккаунта'
                        : (on
                            ? 'Принимаете заказы'
                            : 'Включите, чтобы получать заказы'),
                    style: TextStyle(
                        fontSize: 12,
                        color: on
                            ? AppColors.onBrand.withValues(alpha: 0.7)
                            : AppColors.muted)),
              ],
            ),
          ),
          Switch(
            value: on,
            activeThumbColor: AppColors.onBrand,
            activeTrackColor: AppColors.onBrand.withValues(alpha: 0.35),
            inactiveThumbColor: AppColors.muted,
            inactiveTrackColor: AppColors.surface2,
            onChanged: approved ? _toggleOnline : null,
          ),
        ],
      ),
    );
  }

  Widget _balanceCard(Map stats) {
    final balance = stats['balance'] ?? 0;
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DriverEarningsScreen()));
        _load();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(children: [
          const SoftIcon(Icons.account_balance_wallet_outlined),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Баланс к выплате',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 2),
                Text('${_money.format(balance)} ₸',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text('Вывести',
                style: TextStyle(
                    color: AppColors.onBrand, fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }

  Widget _stat(String label, String value, {bool accent = false}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: accent
                  ? AppColors.brand.withValues(alpha: 0.5)
                  : AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: accent ? AppColors.brand : AppColors.ink)),
          ],
        ),
      );

  Widget _nextTrip(Trip t) {
    final d = DateTime.tryParse(t.scheduledAt)?.toLocal();
    final time = d != null ? DateFormat('HH:mm').format(d) : '';
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => DriverTripScreen(tripId: t.id)));
        _load();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(time,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.brand)),
              ),
              const SizedBox(width: 10),
              InitialAvatar(t.childName ?? 'Р', radius: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t.childName ?? 'Ребёнок',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ]),
            const SizedBox(height: 14),
            _routeLine(AppColors.brand, t.pickupText, top: true),
            _routeLine(AppColors.danger, t.dropoffText, top: false),
          ],
        ),
      ),
    );
  }

  Widget _availableBanner() => GestureDetector(
        onTap: _openTrips,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(children: [
            const SoftIcon(Icons.inbox_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_availableCount > 0
                  ? 'Доступно заказов: $_availableCount'
                  : 'Пока нет доступных заказов'),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ]),
        ),
      );

  Future<void> _openTrips() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const DriverTripsScreen()));
    _load();
  }

  Widget _quickActions() {
    final items = [
      (Icons.assignment_outlined, 'Мои\nпоездки', _openTrips),
      (Icons.inbox_outlined, 'Доступные\nзаказы', _openTrips),
      (Icons.support_agent_outlined, 'Сообщения', () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MessagesScreen()));
      }),
      (Icons.headset_mic_outlined, 'Поддержка', () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MessagesScreen()));
      }),
    ];
    return Row(
      children: items.map((it) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: it.$3,
              child: Container(
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SoftIcon(it.$1,
                      bg: AppColors.brand.withValues(alpha: 0.14), size: 42),
                  const SizedBox(height: 8),
                  Text(it.$2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, height: 1.2)),
                ]),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _routeLine(Color color, String text, {required bool top}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            if (top) Expanded(child: Container(width: 2, color: AppColors.line)),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: top ? 10 : 0),
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }
}
