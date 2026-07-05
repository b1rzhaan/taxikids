import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/trip_status.dart';
import 'driver_trip_screen.dart';

class DriverTripsScreen extends StatefulWidget {
  const DriverTripsScreen({super.key});

  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen> {
  List<Trip> _available = [];
  List<Trip> _mine = [];
  bool _loading = true;
  int? _accepting;

  static const _done = {'completed', 'cancelled'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Future.wait([TripsService.available(), TripsService.list()]);
      _available = r[0];
      _mine = r[1].where((t) => !_done.contains(t.status)).toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _accept(Trip t) async {
    setState(() => _accepting = t.id);
    try {
      final acc = await TripsService.accept(t.id);
      if (!mounted) return;
      setState(() => _accepting = null);
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => DriverTripScreen(tripId: acc.id)));
      _load();
    } catch (e) {
      if (mounted) {
        setState(() => _accepting = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiClient.errorMessage(e))));
      }
    }
  }

  String _time(String iso) {
    try {
      return DateFormat('d MMM, HH:mm', 'ru').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Мои поездки'),
          bottom: TabBar(
            indicatorColor: AppColors.brandDark,
            indicatorWeight: 3,
            labelColor: AppColors.ink,
            unselectedLabelColor: AppColors.muted,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            tabs: [
              Tab(text: 'Текущие (${_mine.length})'),
              Tab(text: 'Доступные (${_available.length})'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
            : TabBarView(children: [
                _list(_mine, mine: true),
                _list(_available, mine: false),
              ]),
      ),
    );
  }

  Widget _list(List<Trip> trips, {required bool mine}) {
    return RefreshIndicator(
      onRefresh: _load,
      child: trips.isEmpty
          ? ListView(children: [
              const SizedBox(height: 130),
              Center(
                child: Column(children: [
                  Icon(mine ? Icons.directions_car_outlined : Icons.inbox_outlined,
                      size: 46, color: AppColors.muted),
                  const SizedBox(height: 8),
                  Text(mine ? 'Нет активных поездок' : 'Нет доступных заказов',
                      style: const TextStyle(color: AppColors.muted)),
                ]),
              ),
            ])
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: trips.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _card(trips[i], mine: mine),
            ),
    );
  }

  Widget _card(Trip t, {required bool mine}) {
    final busy = _accepting == t.id;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: mine
            ? () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => DriverTripScreen(tripId: t.id)));
                _load();
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InitialAvatar(t.childName ?? 'Р', radius: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.childName ?? 'Ребёнок',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                        Text('${_time(t.scheduledAt)} · ${t.priceAmount} ₸',
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  StatusChip(t.status),
                ],
              ),
              const SizedBox(height: 12),
              _routeLine(const Color(0xFF2563EB), t.pickupText, top: true),
              _routeLine(const Color(0xFFF97316), t.dropoffText, top: false),
              if (!mine) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: busy ? null : () => _accept(t),
                    child: busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.ink))
                        : const Text('Принять заказ'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: top ? 8 : 0),
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
