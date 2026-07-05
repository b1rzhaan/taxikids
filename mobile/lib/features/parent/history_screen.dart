import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/trip_status.dart';
import 'trip_tracking_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Trip> _trips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _trips = await TripsService.list();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Вчера';
    return DateFormat('d MMMM', 'ru').format(d);
  }

  @override
  Widget build(BuildContext context) {
    // Group trips by day (most recent first).
    final groups = <String, List<Trip>>{};
    for (final t in _trips) {
      final d = DateTime.tryParse(t.scheduledAt)?.toLocal() ?? DateTime.now();
      groups.putIfAbsent(_dayLabel(d), () => []).add(t);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Мои поездки')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : RefreshIndicator(
              onRefresh: _load,
              child: _trips.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Column(children: [
                          Icon(Icons.route_outlined,
                              size: 46, color: AppColors.muted),
                          SizedBox(height: 8),
                          Text('Поездок пока нет',
                              style: TextStyle(color: AppColors.muted)),
                        ]),
                      ),
                    ])
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        for (final entry in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                            child: Text(entry.key,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppColors.muted)),
                          ),
                          ...entry.value.map(_tripCard),
                        ],
                      ],
                    ),
            ),
    );
  }

  Widget _tripCard(Trip t) {
    final d = DateTime.tryParse(t.scheduledAt)?.toLocal();
    final time = d != null ? DateFormat('HH:mm').format(d) : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => TripTrackingScreen(tripId: t.id))),
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
                          Text(t.childName ?? 'Поездка',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15)),
                          Text('$time · ${t.priceAmount} ₸',
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
              ],
            ),
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
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              if (top)
                Expanded(
                  child: Container(width: 2, color: AppColors.line),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: top ? 8 : 0),
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }
}
