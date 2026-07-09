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
  final String? pickupName;
  final String? pickupPhotoUrl;
  final int pickupCount;
  final bool showTrafficBadge;

  const TripMap({
    super.key,
    this.pickup,
    this.dropoff,
    this.driver,
    this.route = const [],
    this.controller,
    this.onTap,
    this.pickupName,
    this.pickupPhotoUrl,
    this.pickupCount = 0,
    this.showTrafficBadge = false,
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
    return Stack(
      children: [
        FlutterMap(
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
                    strokeWidth: 10,
                    color: const Color(0xFF2F2500),
                  ),
                  Polyline(
                    points: displayRoute,
                    strokeWidth: 6,
                    color: AppColors.brand,
                  ),
                  Polyline(
                    points: displayRoute,
                    strokeWidth: 2,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (pickup != null) _pickupMarker(pickup!),
                if (dropoff != null) _dropoffMarker(dropoff!),
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
        ),
        if (showTrafficBadge)
          Positioned(
            top: 88,
            right: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xEE111827),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.traffic_outlined,
                      color: AppColors.brand,
                      size: 17,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'Пробки учтены',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Marker _pickupMarker(LatLng p) => Marker(
    point: p,
    width: 58,
    height: 70,
    child: Transform.translate(
      offset: const Offset(0, -18),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 2,
            child: Transform.rotate(
              angle: 0.78,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.brand, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: PhotoAvatar(
              name: pickupName ?? 'Ребенок',
              photoUrl: pickupPhotoUrl,
              radius: 20,
            ),
          ),
          if (pickupCount > 1)
            Positioned(
              right: -1,
              top: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  '+${pickupCount - 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Marker _dropoffMarker(LatLng p) => Marker(
    point: p,
    width: 36,
    height: 46,
    child: Transform.translate(
      offset: const Offset(0, -14),
      child: const Icon(
        Icons.location_on,
        color: Color(0xFFF97316),
        size: 38,
        shadows: [
          Shadow(
            color: Color(0x55000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
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
