import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/trip_map.dart';
import '../../widgets/ui.dart';
import 'address_search_screen.dart';
import 'pay_screen.dart';

/// Map-first order screen: map with the route on top, price + order at the bottom.
class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _map = MapController();
  List<Child> _children = [];
  final Set<int> _selectedChildIds = {};
  PickedPoint? _pickup;
  PickedPoint? _dropoff;
  DateTime _when = DateTime.now().add(const Duration(hours: 1));
  RouteEstimate? _estimate;
  bool _loading = true;
  bool _estimating = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    try {
      _children = await ChildrenService.list();
      if (_children.isNotEmpty) {
        final primary = _children.firstWhere(
          (c) => c.isPrimary,
          orElse: () => _children.first,
        );
        _selectedChildIds.add(primary.id);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pick(bool isPickup) async {
    final res = await Navigator.push<PickedPoint>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressSearchScreen(
          title: isPickup ? 'Откуда забрать' : 'Куда отвезти',
          mapInitial: isPickup
              ? const LatLng(43.2389, 76.8897)
              : const LatLng(43.2565, 76.9285),
        ),
      ),
    );
    if (res == null) return;
    setState(() {
      if (isPickup) {
        _pickup = res;
      } else {
        _dropoff = res;
      }
      _estimate = null;
    });
    await _maybeEstimate();
  }

  Future<void> _maybeEstimate() async {
    if (_pickup == null || _dropoff == null) return;
    setState(() => _estimating = true);
    try {
      _estimate = await MapsService.estimate(
        oLat: _pickup!.lat,
        oLng: _pickup!.lng,
        dLat: _dropoff!.lat,
        dLng: _dropoff!.lng,
      );
      _fit();
    } catch (e) {
      _error = ApiClient.errorMessage(e);
    }
    if (mounted) setState(() => _estimating = false);
  }

  void _fit() {
    if (_pickup == null || _dropoff == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _map.fitCamera(
          CameraFit.coordinates(
            coordinates: [
              LatLng(_pickup!.lat, _pickup!.lng),
              LatLng(_dropoff!.lat, _dropoff!.lng),
            ],
            padding: const EdgeInsets.fromLTRB(50, 90, 50, 60),
          ),
        );
      } catch (_) {}
    });
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (t != null) {
      setState(
        () => _when = DateTime(
          _when.year,
          _when.month,
          _when.day,
          t.hour,
          t.minute,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_selectedChildIds.isEmpty || _pickup == null || _dropoff == null) {
      return;
    }
    final selectedChildren = _children
        .where((child) => _selectedChildIds.contains(child.id))
        .toList();
    if (selectedChildren.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final trip = await TripsService.create(
        childId: selectedChildren.first.id,
        childIds: selectedChildren.map((child) => child.id).toList(),
        pickupText: _pickup!.text,
        pickupLat: _pickup!.lat,
        pickupLng: _pickup!.lng,
        dropoffText: _dropoff!.text,
        dropoffLat: _dropoff!.lat,
        dropoffLng: _dropoff!.lng,
        scheduledAtIso: _when.toUtc().toIso8601String(),
      );
      if (!mounted) return;
      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => PayScreen(trip: trip)),
      );
      if (mounted) Navigator.pop(context, paid == true ? trip.id : null);
    } catch (e) {
      setState(() => _error = ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.brand)),
      );
    }
    if (_children.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Заказ поездки')),
        body: _noChildren(),
      );
    }
    final topPad = MediaQuery.of(context).padding.top;
    final selectedChildren = _children
        .where((child) => _selectedChildIds.contains(child.id))
        .toList();
    final primarySelectedChild = selectedChildren.isEmpty
        ? null
        : selectedChildren.first;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: TripMap(
              controller: _map,
              pickup: _pickup == null
                  ? null
                  : LatLng(_pickup!.lat, _pickup!.lng),
              dropoff: _dropoff == null
                  ? null
                  : LatLng(_dropoff!.lat, _dropoff!.lng),
              route: _estimate == null
                  ? const []
                  : toLatLng(_estimate!.polyline),
              pickupName: primarySelectedChild?.fullName,
              pickupPhotoUrl: primarySelectedChild?.photo,
              pickupCount: selectedChildren.length,
              showTrafficBadge: _estimate?.hasTraffic == true,
            ),
          ),
          // Floating back button + title chip over the map.
          Positioned(
            top: topPad + 10,
            left: 14,
            right: 14,
            child: Row(
              children: [
                CircleIconButton(
                  Icons.arrow_back,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'Заказ поездки',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          Align(alignment: Alignment.bottomCenter, child: _sheet()),
        ],
      ),
    );
  }

  Widget _sheet() {
    final selectedCount = _selectedChildIds.length;
    final ready = selectedCount > 0 && _pickup != null && _dropoff != null;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Color(0x55000000), blurRadius: 28)],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            _routeCard(),
            const SizedBox(height: 14),
            const Text(
              'Кого везём',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _childPicker(),
            const SizedBox(height: 14),
            // Pickup time only (no calendar) — for today, tap to change.
            _pill(
              Icons.access_time,
              'Подача: ${DateFormat('HH:mm').format(_when)}',
              _pickTime,
            ),
            if (_estimating) ...[
              const SizedBox(height: 12),
              const Center(
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brand,
                  ),
                ),
              ),
            ] else if (_estimate != null) ...[
              const SizedBox(height: 12),
              _priceRow(_estimate!),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: (ready && _estimate != null && !_submitting)
                    ? _submit
                    : null,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onBrand,
                        ),
                      )
                    : Text(
                        _estimate != null
                            ? selectedCount > 1
                                  ? 'Заказать для $selectedCount детей'
                                  : 'Заказать'
                            : ready
                            ? 'Рассчитываем…'
                            : 'Укажите маршрут',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Yandex-style origin → destination card with a connecting line.
  Widget _routeCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _addrRow(
            dot: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.brand, width: 3),
              ),
            ),
            hint: 'Откуда забрать',
            value: _pickup?.text,
            onTap: () => _pick(true),
            connector: true,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 46),
            child: Divider(height: 1, color: AppColors.line),
          ),
          _addrRow(
            dot: const Icon(Icons.place, color: AppColors.danger, size: 16),
            hint: 'Куда едем?',
            value: _dropoff?.text,
            onTap: () => _pick(false),
            connector: false,
          ),
        ],
      ),
    );
  }

  Widget _addrRow({
    required Widget dot,
    required String hint,
    required String? value,
    required VoidCallback onTap,
    required bool connector,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            SizedBox(width: 16, child: Center(child: dot)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                value ?? hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: value == null ? FontWeight.w500 : FontWeight.w700,
                  color: value == null ? AppColors.muted : AppColors.ink,
                ),
              ),
            ),
            const Icon(Icons.map_outlined, color: AppColors.brand, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _childPicker() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = _children[i];
          final sel = _selectedChildIds.contains(c.id);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (sel && _selectedChildIds.length > 1) {
                  _selectedChildIds.remove(c.id);
                } else {
                  _selectedChildIds.add(c.id);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
              decoration: BoxDecoration(
                color: sel ? AppColors.brand : AppColors.surface2,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  PhotoAvatar(name: c.fullName, photoUrl: c.photo, radius: 17),
                  const SizedBox(width: 8),
                  Text(
                    c.fullName,
                    style: TextStyle(
                      color: sel ? AppColors.onBrand : AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _priceRow(RouteEstimate e) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.brand.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.brand.withValues(alpha: 0.4)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Стоимость поездки',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              '${e.distanceKm} км · ${e.durationMin} мин'
              '${e.hasTraffic ? ' · пробки' : ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        Text(
          '${e.price.round()} ₸',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.brand,
          ),
        ),
      ],
    ),
  );

  Widget _pill(IconData icon, String text, VoidCallback onTap) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.brand),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );

  Widget _noChildren() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.child_care, size: 48, color: AppColors.muted),
          SizedBox(height: 8),
          Text(
            'Сначала добавьте ребёнка',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            'Вкладка «Дети» → «Добавить ребёнка»',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}
