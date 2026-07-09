import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/map_style.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class MapPickerScreen extends StatefulWidget {
  final String title;
  final LatLng initial;
  const MapPickerScreen({
    super.key,
    required this.title,
    this.initial = const LatLng(43.238, 76.912),
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _map = MapController();
  late LatLng _point = widget.initial;
  String _address = '';
  bool _resolving = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    setState(() => _resolving = true);
    final text = await MapsService.reverse(_point.latitude, _point.longitude);
    if (mounted) {
      setState(() {
        _address = text;
        _resolving = false;
      });
    }
  }

  /// Center the picker on the client's precise GPS position.
  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _snack('Разрешите доступ к геолокации в настройках.');
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final here = LatLng(p.latitude, p.longitude);
      setState(() => _point = here);
      _map.move(here, 16);
      _resolve();
    } catch (_) {
      _snack('Не удалось определить местоположение.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: widget.initial,
              initialZoom: 14,
              onTap: (_, p) {
                setState(() => _point = p);
                _resolve();
              },
            ),
            children: [
              kidsTileLayer(),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _point,
                    width: 44,
                    height: 44,
                    child: const Icon(
                      Icons.location_on,
                      color: AppColors.danger,
                      size: 44,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Precise "my location" button — jumps the picker to the client's GPS.
          Positioned(
            right: 16,
            bottom: 190,
            child: FloatingActionButton(
              heroTag: 'myLocation',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.ink,
              onPressed: _locating ? null : _useMyLocation,
              child: _locating
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brandDark,
                      ),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Нажмите на карту, чтобы выбрать точку',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.place, color: AppColors.brandDark),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _resolving
                              ? const Text('Определяем адрес…')
                              : Text(
                                  _address,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(
                          context,
                          PickedPoint(
                            _point.latitude,
                            _point.longitude,
                            _address.isEmpty ? 'Адрес не найден' : _address,
                          ),
                        ),
                        child: const Text('Выбрать эту точку'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
