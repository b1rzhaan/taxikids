import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/map_style.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/trip_map.dart' show toLatLng;

/// In-app turn-by-turn style navigator. Animates the car along the real 2GIS
/// route, keeps the camera locked on it, streams GPS to the backend (so the
/// parent sees live movement), and shows the next turn + remaining distance/ETA.
class NavigationScreen extends StatefulWidget {
  final Trip trip;
  final String targetText;
  const NavigationScreen({super.key, required this.trip, required this.targetText});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  static const _dist = Distance();
  final _map = MapController();
  late final List<LatLng> _route;
  int _i = 0;
  Timer? _timer;
  bool _arrived = false;
  double _heading = 0;

  @override
  void initState() {
    super.initState();
    _route = toLatLng(widget.trip.polyline);
    if (_route.length < 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pop(context));
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 1100), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    if (_i >= _route.length - 1) {
      _timer?.cancel();
      if (mounted) setState(() => _arrived = true);
      return;
    }
    setState(() {
      _heading = _bearing(_route[_i], _route[_i + 1]);
      _i++;
    });
    // Yandex-style camera: rotate the map so travel direction points up, and
    // center it ahead of the car so the car sits in the lower third.
    final center = _offsetAhead(_route[_i], _heading, 130);
    _map.moveAndRotate(center, 17, -_heading);
    try {
      await TripsService.sendLocation(
          widget.trip.id, _route[_i].latitude, _route[_i].longitude);
    } catch (_) {}
  }

  // ── Geometry helpers ────────────────────────────────────────────────
  double _bearing(LatLng a, LatLng b) {
    final dLon = _rad(b.longitude - a.longitude);
    final y = math.sin(dLon) * math.cos(_rad(b.latitude));
    final x = math.cos(_rad(a.latitude)) * math.sin(_rad(b.latitude)) -
        math.sin(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * math.cos(dLon);
    return (_deg(math.atan2(y, x)) + 360) % 360;
  }

  double _rad(double d) => d * math.pi / 180;
  double _deg(double r) => r * 180 / math.pi;

  /// A point [meters] ahead of [from] along [headingDeg] (great-circle).
  LatLng _offsetAhead(LatLng from, double headingDeg, double meters) {
    const r = 6378137.0;
    final d = meters / r;
    final brng = _rad(headingDeg);
    final lat1 = _rad(from.latitude);
    final lon1 = _rad(from.longitude);
    final lat2 = math.asin(
        math.sin(lat1) * math.cos(d) + math.cos(lat1) * math.sin(d) * math.cos(brng));
    final lon2 = lon1 +
        math.atan2(math.sin(brng) * math.sin(d) * math.cos(lat1),
            math.cos(d) - math.sin(lat1) * math.sin(lat2));
    return LatLng(_deg(lat2), _deg(lon2));
  }

  double get _remainingM {
    double m = 0;
    for (int j = _i; j < _route.length - 1; j++) {
      m += _dist(_route[j], _route[j + 1]);
    }
    return m;
  }

  int get _etaMin {
    final t = widget.trip;
    final speed = (t.routeDistanceM > 0 && t.routeDurationS > 0)
        ? t.routeDistanceM / t.routeDurationS
        : 6.7; // ~24 km/h
    return (_remainingM / speed / 60).ceil();
  }

  /// Scan ahead for the next significant heading change (a turn).
  ({double distanceM, String text, IconData icon}) get _nextTurn {
    double acc = 0;
    for (int j = _i + 1; j < _route.length - 1; j++) {
      acc += _dist(_route[j - 1], _route[j]);
      final before = _bearing(_route[j - 1], _route[j]);
      final after = _bearing(_route[j], _route[j + 1]);
      var diff = (after - before + 540) % 360 - 180; // [-180,180]
      if (diff.abs() > 28) {
        if (diff > 0) {
          return (distanceM: acc, text: 'Поворот направо', icon: Icons.turn_right);
        }
        return (distanceM: acc, text: 'Поворот налево', icon: Icons.turn_left);
      }
      if (acc > 1500) break;
    }
    return (distanceM: _remainingM, text: 'Двигайтесь прямо', icon: Icons.straight);
  }

  String _fmt(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} км' : '${m.round()} м';

  @override
  Widget build(BuildContext context) {
    if (_route.length < 2) return const SizedBox.shrink();
    final pos = _route[_i];
    final turn = _nextTurn;
    return Scaffold(
      body: Stack(
        children: [
          // Map fills the whole screen.
          Positioned.fill(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(initialCenter: pos, initialZoom: 16.5),
              children: [
                kidsTileLayer(),
                PolylineLayer(polylines: [
                  Polyline(points: _route, strokeWidth: 7, color: AppColors.brand),
                ]),
                MarkerLayer(markers: [
                  Marker(
                    point: _route.last,
                    width: 22,
                    height: 22,
                    child: const Icon(Icons.flag, color: Color(0xFFF97316), size: 22),
                  ),
                  Marker(
                    point: pos,
                    width: 48,
                    height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Color(0x552563EB), blurRadius: 8),
                        ],
                      ),
                      // Map rotates to course-up, so the arrow always points up.
                      child: const Icon(Icons.navigation,
                          color: Colors.white, size: 26),
                    ),
                  ),
                ]),
              ],
            ),
          ),

          // Compact maneuver banner pinned to the top.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _maneuverBanner(turn),
              ),
            ),
          ),

          // Bottom info / arrival, pinned to the bottom.
          Positioned(left: 0, right: 0, bottom: 0, child: _bottomBar()),
        ],
      ),
    );
  }

  Widget _maneuverBanner(({double distanceM, String text, IconData icon}) turn) {
    final arrived = _arrived;
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: arrived ? AppColors.success : AppColors.ink,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12)],
      ),
      child: Row(
        children: [
          _closeButton(),
          const SizedBox(width: 8),
          Icon(arrived ? Icons.check_circle : turn.icon,
              color: arrived ? Colors.white : AppColors.brand, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: arrived
                ? const Text('Вы на месте',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('через ${_fmt(turn.distanceM)}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      Text(turn.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _closeButton() => InkResponse(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.close, color: Colors.white, size: 20),
        ),
      );

  Widget _bottomBar() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 16)],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.place, color: Color(0xFFF97316), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(widget.targetText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat(_arrived ? '0 мин' : '$_etaMin мин', 'осталось'),
                _stat(_fmt(_remainingM), 'до цели'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: _arrived
                    ? ElevatedButton.styleFrom(backgroundColor: AppColors.success)
                    : null,
                child: Text(_arrived ? 'Готово' : 'Свернуть навигатор',
                    style: TextStyle(
                        color: _arrived ? Colors.white : AppColors.ink)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String v, String l) => Column(
        children: [
          Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(l, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      );

}
