import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import 'halyk_checkout_screen.dart';
import 'hosted_checkout_screen.dart';

class PayScreen extends StatefulWidget {
  final Trip trip;
  const PayScreen({super.key, required this.trip});

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  bool _processing = false;
  bool _paid = false;
  String? _error;
  String _method = 'card'; // 'card' | 'cash'

  Future<void> _payCash() async {
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      await PaymentsService.payCash(widget.trip.id);
      setState(() => _paid = true);
    } catch (e) {
      setState(() => _error = ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _pay() async {
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final res = await PaymentsService.create(widget.trip.id);
      final provider = '${res['provider']}';

      if (provider == 'halyk' && res['payment_object'] != null) {
        // Real Halyk ePay hosted card form in a WebView.
        if (!mounted) return;
        final po = Map<String, dynamic>.from(res['payment_object'] ?? {});
        final invoiceId = '${res['provider_ref']}';
        final ok = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => HalykCheckoutScreen(
              pageUrl:
                  '${AppConfig.apiBase}/payments/halyk/page/${res['payment_id']}/',
              backLink: '${po['backLink']}',
              failLink: '${po['failureBackLink']}',
              onSuccess: () async =>
                  (await PaymentsService.halykConfirm(invoiceId)) == 'success',
            ),
          ),
        );
        if (ok == true) {
          setState(() => _paid = true);
        } else {
          setState(() => _error = 'Оплата не завершена');
        }
      } else if (provider == 'stripe' && '${res['redirect_url']}'.isNotEmpty) {
        // Stripe Checkout in test/demo mode. Production Kazakhstan acquiring can
        // later be switched to Halyk/ioka/Kaspi via the same backend provider.
        if (!mounted) return;
        final meta = Map<String, dynamic>.from(res['payment_object'] ?? {});
        final sessionId = '${res['provider_ref']}';
        final ok = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => HostedCheckoutScreen(
              title: 'Stripe test checkout',
              pageUrl: '${res['redirect_url']}',
              successPrefix: '${meta['success_prefix']}',
              failPrefix: '${meta['cancel_prefix']}',
              onSuccess: () async =>
                  (await PaymentsService.stripeConfirm(sessionId)) == 'success',
            ),
          ),
        );
        if (ok == true) {
          setState(() => _paid = true);
        } else {
          setState(() => _error = 'Stripe checkout was not completed');
        }
      } else {
        // Mock provider: emulate the hosted checkout succeeding.
        final ref = '${res['provider_ref']}';
        final status = await PaymentsService.mockCheckout(ref, success: true);
        if (status == 'success') {
          setState(() => _paid = true);
        } else {
          setState(() => _error = 'Оплата не прошла, попробуйте ещё раз');
        }
      }
    } catch (e) {
      setState(() => _error = ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final cash = _method == 'cash';
    return Scaffold(
      appBar: AppBar(
        title: Text(_paid ? (cash ? 'Заказ оформлен' : 'Поездка оплачена') : 'Оплата'),
        automaticallyImplyLeading: !_paid,
      ),
      body: _paid ? _success(t) : _checkout(t),
    );
  }

  Widget _checkout(Trip t) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row('Ребёнок', t.childName ?? '—'),
                  const Divider(),
                  _row('Маршрут', '${t.pickupText} → ${t.dropoffText}'),
                  const Divider(),
                  _row('Расстояние',
                      '${(t.routeDistanceM / 1000).toStringAsFixed(1)} км'),
                  const Divider(),
                  _row('В пути (с пробками)', '${(t.routeDurationS / 60).round()} мин'),
                  const Divider(),
                  _row('К оплате', '${t.priceAmount} ₸', bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Способ оплаты',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          _methodTile(
            value: 'card',
            icon: Icons.credit_card,
            title: 'Картой',
            subtitle: 'Оплата онлайн сейчас',
          ),
          const SizedBox(height: 8),
          _methodTile(
            value: 'cash',
            icon: Icons.payments_outlined,
            title: 'Наличными',
            subtitle: 'Оплата водителю в конце поездки',
          ),
          const Spacer(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ),
          Row(children: [
            Icon(_method == 'cash' ? Icons.info_outline : Icons.lock_outline,
                size: 16, color: AppColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  _method == 'cash'
                      ? 'Водитель примет оплату наличными по завершении поездки.'
                      : 'Безопасная оплата картой. Тестовый режим (mock).',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _processing ? null : (_method == 'cash' ? _payCash : _pay),
              child: _processing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.onBrand))
                  : Text(_method == 'cash'
                      ? 'Заказать за наличные · ${t.priceAmount} ₸'
                      : 'Оплатить ${t.priceAmount} ₸'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodTile({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _method == value;
    return InkWell(
      onTap: _processing ? null : () => setState(() => _method = value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.line,
            width: selected ? 2 : 1,
          ),
          color: selected ? AppColors.brand.withValues(alpha: 0.12) : AppColors.surface2,
        ),
        child: Row(children: [
          Icon(icon, color: selected ? AppColors.ink : AppColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(subtitle,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.brand : AppColors.muted, size: 20),
        ]),
      ),
    );
  }

  Widget _success(Trip t) {
    final cash = _method == 'cash';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 90,
            width: 90,
            decoration: BoxDecoration(
                color: cash ? AppColors.brand : AppColors.success,
                shape: BoxShape.circle),
            child: Icon(cash ? Icons.check_circle_outline : Icons.check,
                color: cash ? AppColors.ink : Colors.white, size: 54),
          ),
          const SizedBox(height: 20),
          Text(cash ? 'Заказ оформлен!' : 'Оплачено успешно!',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('${t.priceAmount} ₸ · Поездка №${t.id}',
              style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 8),
          if (cash)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                  'Оплата наличными водителю в конце поездки — приготовьте ${t.priceAmount} ₸.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            )
          else
            const Text('Оплата прошла. Оператор назначит водителя.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 8),
          const Text('Вы получите уведомление, когда водителя назначат.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted)),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Готово'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(color: AppColors.muted))),
            const SizedBox(width: 12),
            Expanded(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                      fontSize: bold ? 18 : 14)),
            ),
          ],
        ),
      );
}
