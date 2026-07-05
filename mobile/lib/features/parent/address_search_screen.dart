import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import 'map_picker_screen.dart';

/// Yandex-style address search: type an address, pick from live 2GIS
/// suggestions or recent addresses, or fall back to picking on the map.
class AddressSearchScreen extends StatefulWidget {
  final String title;
  final LatLng mapInitial;
  const AddressSearchScreen({
    super.key,
    required this.title,
    this.mapInitial = const LatLng(43.238, 76.912),
  });

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<PickedPoint> _suggestions = [];
  List<PickedPoint> _recent = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    try {
      final r = await AddressService.recent();
      if (mounted) setState(() => _recent = r);
    } catch (_) {}
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final res = await MapsService.suggest(q);
        if (mounted) setState(() => _suggestions = res);
      } catch (_) {
        if (mounted) setState(() => _suggestions = []);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  Future<void> _choose(PickedPoint p) async {
    await AddressService.save(p);
    if (mounted) Navigator.pop(context, p);
  }

  Future<void> _openMap() async {
    final res = await Navigator.push<PickedPoint>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MapPickerScreen(title: widget.title, initial: widget.mapInitial),
      ),
    );
    if (res != null) _choose(res);
  }

  @override
  Widget build(BuildContext context) {
    final typing = _controller.text.trim().length >= 2;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Например: Абая 45',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined, color: AppColors.brandDark),
            title: const Text('Выбрать на карте',
                style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: _openMap,
          ),
          const Divider(height: 1),
          if (_loading) const LinearProgressIndicator(color: AppColors.brand),
          Expanded(
            child: typing
                ? _list(_suggestions, empty: 'Ничего не найдено')
                : _recentList(),
          ),
        ],
      ),
    );
  }

  Widget _recentList() {
    if (_recent.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Начните вводить адрес — появятся подсказки',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted)),
        ),
      );
    }
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Недавние адреса',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ),
        ..._recent.map((p) => _tile(p, Icons.history)),
      ],
    );
  }

  Widget _list(List<PickedPoint> items, {required String empty}) {
    if (items.isEmpty && !_loading) {
      return Center(
        child: Text(empty, style: const TextStyle(color: AppColors.muted)),
      );
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) => _tile(items[i], Icons.place_outlined),
    );
  }

  Widget _tile(PickedPoint p, IconData icon) => ListTile(
        leading: Icon(icon, color: AppColors.muted),
        title: Text(p.text),
        onTap: () => _choose(p),
      );
}
