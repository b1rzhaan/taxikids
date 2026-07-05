import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../services/services.dart';
import 'bank_checkout_screen.dart';
import 'halyk_checkout_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  num _balance = 0;
  List _tx = [];
  List _plans = [];
  List _subs = [];
  bool _loading = true;
  final _money = NumberFormat.decimalPattern('ru');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final b = await WalletService.balance();
      _balance = b['balance'] ?? 0;
      _tx = await WalletService.transactions();
      _plans = await WalletService.plans();
      _subs = await WalletService.subscriptions();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _topUp() async {
    final amount = await showModalBottomSheet<num>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AmountSheet(),
    );
    if (amount == null || amount <= 0) return;
    bool paid = false;
    try {
      final res = await WalletService.topUpCreate(amount);
      if (!mounted) return;
      if (res['provider'] == 'halyk' && res['payment_object'] != null) {
        final po = Map<String, dynamic>.from(res['payment_object']);
        final ref = '${res['ref']}';
        paid = (await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => HalykCheckoutScreen(
                  pageUrl:
                      '${AppConfig.apiBase}/wallet/topup/halyk/page/$ref/',
                  backLink: '${po['backLink']}',
                  failLink: '${po['failureBackLink']}',
                  onSuccess: () async =>
                      (await WalletService.topUpCheckout(ref)) == 'success',
                ),
              ),
            )) ==
            true;
      } else {
        paid = (await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      BankCheckoutScreen(amount: amount, ref: '${res['ref']}')),
            )) ==
            true;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiClient.errorMessage(e))));
      }
    }
    if (paid && mounted) {
      _load();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Баланс пополнен')));
    }
  }

  Future<void> _buyPlan(Map plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(plan['name']),
        content: Text(
            'Списать ${_money.format(plan['price'])} ₸ с баланса за абонемент на ${plan['trips_count']} поездок?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Купить')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await WalletService.buySubscription(plan['id']);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiClient.errorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Финансы')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _balanceCard(),
                  const SizedBox(height: 20),
                  if (_subs.isNotEmpty) ...[
                    _sectionTitle('Активный абонемент'),
                    ..._subs.map(_activeSubCard),
                    const SizedBox(height: 20),
                  ],
                  _sectionTitle('Способы оплаты'),
                  _paymentMethod(),
                  const SizedBox(height: 20),
                  if (_plans.isNotEmpty) ...[
                    _sectionTitle('Абонементы'),
                    ..._plans.map(_planCard),
                    const SizedBox(height: 20),
                  ],
                  _sectionTitle('История операций'),
                  const SizedBox(height: 4),
                  if (_tx.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Пока нет операций',
                          style: TextStyle(color: AppColors.muted)),
                    )
                  else
                    ..._tx.map(_txTile),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      );

  Widget _balanceCard() {
    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Баланс кошелька',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Icon(Icons.account_balance_wallet, color: AppColors.ink),
            ],
          ),
          const SizedBox(height: 8),
          Text('${_money.format(_balance)} ₸',
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.surface2, foregroundColor: AppColors.ink),
              onPressed: _topUp,
              icon: const Icon(Icons.add),
              label: const Text('Пополнить через банк'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentMethod() => Card(
        child: ListTile(
          leading: const Icon(Icons.credit_card, color: AppColors.brandDark),
          title: const Text('Visa •••• 4567',
              style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Основная карта'),
          trailing: const Icon(Icons.check_circle, color: AppColors.success),
        ),
      );

  Widget _activeSubCard(dynamic s) {
    final plan = s['plan'] ?? {};
    return Card(
      color: AppColors.brandSoft,
      child: ListTile(
        leading: const Text('🎫', style: TextStyle(fontSize: 26)),
        title: Text(plan['name'] ?? 'Абонемент',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
            'Осталось поездок: ${s['trips_remaining']} · до ${s['valid_until']}'),
      ),
    );
  }

  Widget _planCard(dynamic p) => Card(
        child: ListTile(
          title: Text(p['name'],
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
              '${p['trips_count']} поездок · ${_money.format(p['price_per_trip'])} ₸/поездка'),
          trailing: ElevatedButton(
            onPressed: () => _buyPlan(p as Map),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14)),
            child: Text('${_money.format(p['price'])} ₸'),
          ),
        ),
      );

  Widget _txTile(dynamic t) {
    final amt = num.tryParse('${t['amount']}') ?? 0;
    final positive = amt >= 0;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              (positive ? AppColors.success : AppColors.danger).withValues(alpha: 0.12),
          child: Icon(positive ? Icons.arrow_downward : Icons.arrow_upward,
              color: positive ? AppColors.success : AppColors.danger, size: 20),
        ),
        title: Text(t['note'] ?? t['kind'] ?? ''),
        trailing: Text(
          '${positive ? '+' : ''}${_money.format(amt)} ₸',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: positive ? AppColors.success : AppColors.ink),
        ),
      ),
    );
  }
}

class _AmountSheet extends StatefulWidget {
  const _AmountSheet();
  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  final _c = TextEditingController(text: '5000');
  static const _presets = [3000, 5000, 10000, 20000];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Сумма пополнения',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: _presets
                  .map((p) => ActionChip(
                        backgroundColor: AppColors.brandSoft,
                        side: BorderSide.none,
                        label: Text('$p ₸'),
                        onPressed: () => setState(() => _c.text = '$p'),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _c,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(suffixText: '₸'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.pop(context, num.tryParse(_c.text) ?? 0),
                child: const Text('Перейти к оплате'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
