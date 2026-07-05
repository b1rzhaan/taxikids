import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/rating_sheet.dart';
import '../../widgets/trip_map.dart';
import '../../widgets/trip_status.dart';
import '../../widgets/ui.dart';

class TripTrackingScreen extends StatefulWidget {
  final int tripId;
  const TripTrackingScreen({super.key, required this.tripId});

  @override
  State<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends State<TripTrackingScreen> {
  final _map = MapController();
  Trip? _trip;
  LatLng? _driverPos;
  Timer? _timer;
  bool _ratePrompted = false;
  bool _fitDone = false;

  void _fitMap(Trip t) {
    if (_fitDone) return;
    _fitDone = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _map.fitCamera(CameraFit.coordinates(
          coordinates: [
            LatLng(t.pickupLat, t.pickupLng),
            LatLng(t.dropoffLat, t.dropoffLng),
          ],
          padding: const EdgeInsets.fromLTRB(50, 90, 50, 60),
        ));
      } catch (_) {}
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  void _maybePromptRating() {
    final t = _trip;
    if (t == null || _ratePrompted) return;
    if (t.status == 'completed' && t.myRating == null) {
      _ratePrompted = true;
      _timer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showRatingSheet(
          context,
          tripId: t.id,
          title: 'Оцените поездку',
          subtitle: t.driver?.fullName ?? 'Водитель',
        );
        _load();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final t = await TripsService.get(widget.tripId);
      if (mounted) setState(() => _trip = t);
      _fitMap(t);
      _maybePromptRating();
    } catch (_) {}
    _poll();
  }

  Future<void> _poll() async {
    final loc = await TripsService.track(widget.tripId);
    if (loc != null && mounted) {
      setState(() => _driverPos =
          LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble()));
    }
    // Refresh status quietly.
    try {
      final t = await TripsService.get(widget.tripId);
      if (mounted) setState(() => _trip = t);
      _maybePromptRating();
    } catch (_) {}
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Отменить поездку?'),
        content: const Text('Если поездка оплачена — средства вернутся.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Нет')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Отменить поездку',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final t = await TripsService.cancel(widget.tripId);
      if (mounted) setState(() => _trip = t);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = _trip;
    return Scaffold(
      appBar: AppBar(title: const Text('Поездка')),
      body: t == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : Column(
              children: [
                Expanded(
                  child: TripMap(
                    controller: _map,
                    pickup: LatLng(t.pickupLat, t.pickupLng),
                    dropoff: LatLng(t.dropoffLat, t.dropoffLng),
                    driver: _driverPos,
                    route: toLatLng(t.polyline),
                  ),
                ),
                _sheet(t),
              ],
            ),
    );
  }

  Widget _sheet(Trip t) {
    final canCancel = {'created', 'waiting_payment', 'paid', 'driver_assigned'}
        .contains(t.status);
    final info = statusInfo(t.status);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 24)],
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                InitialAvatar(t.childName ?? 'Р', radius: 23),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.childName ?? 'Поездка',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(info.label,
                          style: TextStyle(
                              color: info.color,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ],
                  ),
                ),
                Text('${t.priceAmount} ₸',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 16),
            _stepper(t.status),
            const SizedBox(height: 16),
            _routeCard(t),
            const SizedBox(height: 12),
            if (t.driver != null)
              _driverCard(t.driver!)
            else if (t.status != 'cancelled' && t.status != 'completed')
              _searching(),
            if (canCancel) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cancel,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(color: Colors.red.shade100)),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Отменить поездку'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Status stepper ────────────────────────────────────────────────
  static const _steps = [
    ('Заказ', Icons.receipt_long),
    ('Водитель', Icons.directions_car),
    ('В машине', Icons.child_care),
    ('Доставлен', Icons.flag),
  ];

  int _stepIndex(String s) {
    switch (s) {
      case 'created':
      case 'waiting_payment':
      case 'paid':
        return 0;
      case 'driver_assigned':
      case 'driver_on_way':
      case 'driver_arrived':
        return 1;
      case 'child_picked_up':
      case 'in_progress':
        return 2;
      case 'child_delivered':
      case 'completed':
        return 3;
      default:
        return -1;
    }
  }

  Widget _stepper(String status) {
    if (status == 'cancelled') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(14)),
        child: const Text('Поездка отменена',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.danger, fontWeight: FontWeight.w700)),
      );
    }
    final cur = _stepIndex(status);
    return Row(
      children: List.generate(_steps.length, (i) {
        final done = i <= cur;
        final current = i == cur;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                      child: i == 0
                          ? const SizedBox()
                          : Container(
                              height: 3,
                              color: i <= cur ? AppColors.brand : AppColors.line)),
                  Container(
                    height: 30,
                    width: 30,
                    decoration: BoxDecoration(
                      color: done ? AppColors.brand : AppColors.surface2,
                      shape: BoxShape.circle,
                      border: current
                          ? Border.all(color: AppColors.brandDark, width: 2)
                          : null,
                    ),
                    child: Icon(_steps[i].$2,
                        size: 16,
                        color: done ? AppColors.ink : Colors.grey.shade400),
                  ),
                  Expanded(
                      child: i == _steps.length - 1
                          ? const SizedBox()
                          : Container(
                              height: 3,
                              color: i < cur ? AppColors.brand : AppColors.line)),
                ],
              ),
              const SizedBox(height: 4),
              Text(_steps[i].$1,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                      color: done ? AppColors.ink : AppColors.muted)),
            ],
          ),
        );
      }),
    );
  }

  Widget _routeCard(Trip t) {
    final km = (t.routeDistanceM / 1000).toStringAsFixed(1);
    final min = (t.routeDurationS / 60).round();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _addr(const Color(0xFF2563EB), t.pickupText),
          const Padding(
            padding: EdgeInsets.only(left: 5),
            child: SizedBox(
                height: 14,
                child: VerticalDivider(width: 8, thickness: 1.5)),
          ),
          _addr(const Color(0xFFF97316), t.dropoffText),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metric('$km км', 'путь'),
              _metric('$min мин', 'в пути'),
              _metric('${t.priceAmount} ₸', 'стоимость'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addr(Color color, String text) => Row(
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      );

  Widget _metric(String v, String l) => Column(
        children: [
          Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(l, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
        ],
      );

  Widget _searching() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.surface2, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: const [
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: AppColors.brand),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ищем водителя…',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  SizedBox(height: 2),
                  Text('Подбираем проверенного водителя рядом',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );

  /// Template-style driver card: photo, plate, rating, car, stats, call CTA.
  Widget _driverCard(DriverInfo d) {
    final v = d.vehicle;
    final car = v == null ? '' : '${v['make']} ${v['model']}';
    final plate = '${v?['plate_number'] ?? '—'}';
    final seats = v?['seats'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialAvatar(d.fullName, radius: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    if (car.isNotEmpty)
                      Text(car,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PlateBadge(plate),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.star, color: AppColors.brand, size: 15),
                    const SizedBox(width: 3),
                    Text(d.rating,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ],
              ),
            ],
          ),
          Center(
            child: Image.asset('assets/car.png',
                height: 78, fit: BoxFit.contain),
          ),
          const SizedBox(height: 6),
          Row(children: [
            if (seats != null) ...[
              Expanded(
                  child: StatPill(
                      icon: Icons.event_seat_outlined,
                      value: '$seats',
                      label: 'Мест')),
              const SizedBox(width: 10),
            ],
            Expanded(
                child: StatPill(
                    icon: Icons.workspace_premium_outlined,
                    value: '${d.experienceYears} л',
                    label: 'Стаж')),
            const SizedBox(width: 10),
            Expanded(
                child: StatPill(
                    icon: Icons.child_care_outlined,
                    value: d.hasChildSeat ? 'Есть' : 'Нет',
                    label: 'Кресло')),
          ]),
          if (d.phone.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => launchUrl(Uri.parse('tel:${d.phone}')),
                icon: const Icon(Icons.phone),
                label: const Text('Позвонить водителю'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
