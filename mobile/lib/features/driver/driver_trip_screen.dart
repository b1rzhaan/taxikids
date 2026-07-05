import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/rating_sheet.dart';
import '../../widgets/trip_map.dart';
import '../../widgets/trip_status.dart';
import 'dgis_web_navigation_screen.dart';

/// Maps the current status to the next state-machine event + button label.
const _nextAction = {
  'driver_assigned': ['depart', 'Выехал к ребёнку'],
  'driver_on_way': ['arrive', 'Я на месте'],
  'driver_arrived': ['pick_up', 'Забрал ребёнка'],
  'child_picked_up': ['start', 'Начать поездку'],
  'in_progress': ['deliver', 'Ребёнок доставлен'],
  'child_delivered': ['complete', 'Завершить поездку'],
};

class DriverTripScreen extends StatefulWidget {
  final int tripId;
  const DriverTripScreen({super.key, required this.tripId});

  @override
  State<DriverTripScreen> createState() => _DriverTripScreenState();
}

class _DriverTripScreenState extends State<DriverTripScreen> {
  Trip? _trip;
  bool _busy = false;
  LatLng? _myPos; // driver's own live GPS position
  Timer? _gpsTimer;

  static const _activeStatuses = {
    'driver_assigned', 'driver_on_way', 'driver_arrived',
    'child_picked_up', 'in_progress', 'child_delivered',
  };

  // Before pickup the driver heads to the child; after — to the destination.
  bool get _headingToPickup => {
        'driver_assigned',
        'driver_on_way',
        'driver_arrived',
      }.contains(_trip?.status);

  ({double lat, double lng, String text})? get _target {
    final t = _trip;
    if (t == null) return null;
    return _headingToPickup
        ? (lat: t.pickupLat, lng: t.pickupLng, text: t.pickupText)
        : (lat: t.dropoffLat, lng: t.dropoffLng, text: t.dropoffText);
  }

  @override
  void initState() {
    super.initState();
    _load();
    // Push the driver's real GPS every 5s while the trip is active, so both
    // the parent and the cabinet map track the taxi live.
    _pushGps();
    _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pushGps());
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final t = await TripsService.get(widget.tripId);
      if (mounted) setState(() => _trip = t);
    } catch (_) {}
  }

  Future<void> _pushGps() async {
    final t = _trip;
    if (t != null && !_activeStatuses.contains(t.status)) return;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
      if (!mounted) return;
      setState(() => _myPos = LatLng(p.latitude, p.longitude));
      await TripsService.sendLocation(widget.tripId, p.latitude, p.longitude);
    } catch (_) {
      // GPS/network hiccup — try again on the next tick.
    }
  }

  Future<void> _advance() async {
    final t = _trip;
    if (t == null) return;
    final action = _nextAction[t.status];
    if (action == null) return;
    setState(() => _busy = true);
    try {
      final updated = await TripsService.changeStatus(t.id, action[0]);
      if (mounted) setState(() => _trip = updated);
      if (updated.status == 'completed' && updated.myRating == null && mounted) {
        await showRatingSheet(
          context,
          tripId: updated.id,
          title: 'Оцените заказ',
          subtitle: updated.childName ?? '',
        );
        if (mounted) _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiClient.errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openNavigator() {
    final t = _trip;
    final tg = _target;
    if (t == null || tg == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DgisWebNavigationScreen(
          trip: t,
          targetLat: tg.lat,
          targetLng: tg.lng,
          targetText: tg.text,
          headingToPickup: _headingToPickup,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _trip;
    return Scaffold(
      appBar: AppBar(title: Text('Заказ №${widget.tripId}')),
      body: t == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : Column(
              children: [
                Expanded(
                  child: TripMap(
                    pickup: LatLng(t.pickupLat, t.pickupLng),
                    dropoff: LatLng(t.dropoffLat, t.dropoffLng),
                    route: toLatLng(t.polyline),
                    driver: _myPos,
                  ),
                ),
                _panel(t),
              ],
            ),
    );
  }

  Widget _panel(Trip t) {
    final action = _nextAction[t.status];
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(t.childName ?? 'Ребёнок',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              StatusChip(t.status),
            ],
          ),
          const SizedBox(height: 6),
          _infoRow(Icons.trip_origin, t.pickupText),
          _infoRow(Icons.place, t.dropoffText),
          if (t.child?.noteForDriver.isNotEmpty ?? false)
            _infoRow(Icons.info_outline, t.child!.noteForDriver),
          if (t.paymentMethod == 'cash' && t.paymentStatus != 'paid') ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.success.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined, color: AppColors.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Оплата наличными',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.muted)),
                        Text('Возьмите с клиента ${t.priceAmount} ₸',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (action != null && _target != null) ...[
            _targetBanner(t),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: t.polyline.length >= 2 ? _openNavigator : null,
                icon: const Icon(Icons.navigation_outlined),
                label: Text(_headingToPickup
                    ? 'Навигатор к ребёнку'
                    : 'Навигатор до места'),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (action != null)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _busy ? null : _advance,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.onBrand))
                    : Text(
                        (t.status == 'child_delivered' &&
                                t.paymentMethod == 'cash')
                            ? 'Получить ${t.priceAmount} ₸ и завершить'
                            : action[1],
                        style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Text('Поездка завершена ✅',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.success)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _targetBanner(Trip t) {
    final km = (t.routeDistanceM / 1000).toStringAsFixed(1);
    final min = (t.routeDurationS / 60).round();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.navigation, color: AppColors.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_headingToPickup ? 'Едем к ребёнку' : 'Везём ребёнка',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                Text(_target?.text ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('~$km км · $min мин',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.muted),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
