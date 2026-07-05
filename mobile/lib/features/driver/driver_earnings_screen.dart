import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../services/services.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  Map<String, dynamic>? _me;
  List _earnings = [];
  bool _loading = true;
  bool _withdrawing = false;
  int _period = 0; // 0 today, 1 week, 2 month
  final _money = NumberFormat.decimalPattern('ru');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _me = await DriverService.me();
      _earnings = await DriverService.earnings();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _withdraw() async {
    setState(() => _withdrawing = true);
    try {
      await DriverService.requestPayout();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Заявка на выплату создана')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiClient.errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = (_me?['stats'] as Map?) ?? {};
    final periodKey = ['earned_today', 'earned_week', 'earned_month'][_period];
    final periodLabel = ['Сегодня', 'За неделю', 'За месяц'][_period];
    final earned = stats[periodKey] ?? 0;
    final balance = stats['balance'] ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Заработок')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _segmented(),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        colors: [AppColors.brand, Color(0xFFFFB300)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$periodLabel заработали',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.onBrand)),
                        const SizedBox(height: 6),
                        Text('${_money.format(earned)} ₸',
                            style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: AppColors.onBrand)),
                        const SizedBox(height: 8),
                        Row(children: [
                          _miniStat(Icons.check_circle_outline,
                              '${stats['completed_total'] ?? 0}', 'поездок'),
                          const SizedBox(width: 20),
                          _miniStat(Icons.today,
                              '${stats['trips_today'] ?? 0}', 'сегодня'),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Выплаты',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Доступно к выводу',
                                  style: TextStyle(
                                      color: AppColors.muted, fontSize: 12)),
                              Text('${_money.format(balance)} ₸',
                                  style: const TextStyle(
                                      fontSize: 22, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed:
                              (_withdrawing || (num.tryParse('$balance') ?? 0) <= 0)
                                  ? null
                                  : _withdraw,
                          child: _withdrawing
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.onBrand))
                              : const Text('Вывести'),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('История операций',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (_earnings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Пока нет начислений',
                          style: TextStyle(color: AppColors.muted)),
                    )
                  else
                    ..._earnings.map((e) => Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.brandSoft,
                              child: Icon(Icons.directions_car,
                                  color: AppColors.brandDark, size: 20),
                            ),
                            title: Text('Поездка №${e['trip']}',
                                style:
                                    const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${e['status']}'),
                            trailing: Text(
                                '+${_money.format(num.tryParse('${e['amount']}') ?? 0)} ₸',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.success)),
                          ),
                        )),
                ],
              ),
            ),
    );
  }

  Widget _segmented() {
    final labels = ['Сегодня', 'Неделя', 'Месяц'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: AppColors.surface2, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: List.generate(3, (i) {
          final sel = i == _period;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _period = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: sel ? AppColors.brand : Colors.transparent,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                        color: sel ? AppColors.onBrand : AppColors.muted)),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _miniStat(IconData icon, String v, String l) => Row(
        children: [
          Icon(icon, size: 16, color: AppColors.onBrand),
          const SizedBox(width: 4),
          Text('$v $l',
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.onBrand)),
        ],
      );
}
