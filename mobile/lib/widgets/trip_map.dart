import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/map_style.dart';
import '../core/theme.dart';

/// Reusable map. Renders the (real 2GIS-derived) route polyline on free OSM
/// tiles, with pickup / dropoff / live-driver markers. No API key required.
class TripMap extends StatelessWidget {
  final LatLng? pickup;
  final LatLng? dropoff;
  final LatLng? driver;
  final List<LatLng> route;
  final MapController? controller;
  final void Function(LatLng)? onTap;

  const TripMap({
    super.key,
    this.pickup,
    this.dropoff,
    this.driver,
    this.route = const [],
    this.controller,
    this.onTap,
  });

  LatLng get _center {
    if (pickup != null && dropoff != null) {
      return LatLng(
        (pickup!.latitude + dropoff!.latitude) / 2,
        (pickup!.longitude + dropoff!.longitude) / 2,
      );
    }
    return pickup ?? dropoff ?? const LatLng(43.238, 76.912); // Almaty
  }

  @override
  Widget build(BuildContext context) {
    final displayRoute = route.length == 2 ? softenedRoute(route) : route;
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: 13,
        onTap: onTap == null ? null : (_, p) => onTap!(p),
      ),
      children: [
        kidsTileLayer(),
        if (displayRoute.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: displayRoute,
                strokeWidth: 6,
                color: AppColors.brand,
                borderStrokeWidth: 3,
                borderColor: const Color(0xFF6B4E00),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (pickup != null) _dot(pickup!, const Color(0xFF2563EB)),
            if (dropoff != null) _dot(dropoff!, const Color(0xFFF97316)),
            if (driver != null)
              Marker(
                point: driver!,
                width: 40,
                height: 40,
                child: const Text('🚕', style: TextStyle(fontSize: 30)),
              ),
          ],
        ),
      ],
    );
  }

  Marker _dot(LatLng p, Color color) => Marker(
    point: p,
    width: 22,
    height: 22,
    child: Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
    ),
  );
}

List<LatLng> toLatLng(List<List<double>> raw) =>
    raw.map((p) => LatLng(p[0], p[1])).toList();

List<LatLng> softenedRoute(List<LatLng> raw) {
  if (raw.length != 2) return raw;
  final a = raw.first;
  final b = raw.last;
  final latDelta = b.latitude - a.latitude;
  final lngDelta = b.longitude - a.longitude;
  final sign = (a.latitude + a.longitude) < (b.latitude + b.longitude) ? 1 : -1;
  final bendLat = (lngDelta.abs() * 0.18).clamp(0.004, 0.018).toDouble() * sign;
  final bendLng =
      (latDelta.abs() * 0.18).clamp(0.004, 0.018).toDouble() * -sign;
  return [
    a,
    LatLng(a.latitude + latDelta * 0.18, a.longitude),
    LatLng(
      (a.latitude + b.latitude) / 2 + bendLat,
      (a.longitude + b.longitude) / 2 + bendLng,
    ),
    LatLng(b.latitude - latDelta * 0.18, b.longitude),
    b,
  ];
}
