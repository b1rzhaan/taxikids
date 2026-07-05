import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../services/services.dart';

/// Mock bank checkout page — mimics a real PSP hosted card form.
/// On "pay" it calls the top-up callback which credits the wallet.
class BankCheckoutScreen extends StatefulWidget {
  final num amount;
  final String? ref; // pre-created top-up ref (skip create if provided)
  const BankCheckoutScreen({super.key, required this.amount, this.ref});

  @override
  State<BankCheckoutScreen> createState() => _BankCheckoutScreenState();
}

class _BankCheckoutScreenState extends State<BankCheckoutScreen> {
  final _card = TextEditingController(text: '4400 4301 2345 4567');
  final _exp = TextEditingController(text: '12/27');
  final _cvv = TextEditingController(text: '123');
  bool _paying = false;

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      final ref = widget.ref ??
          '${(await WalletService.topUpCreate(widget.amount))['ref']}';
      final status = await WalletService.topUpCheckout(ref, success: true);
      if (mounted) Navigator.pop(context, status == 'success');
    } catch (e) {
      if (mounted) {
        setState(() => _paying = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiClient.errorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E2A47),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E2A47),
        foregroundColor: Colors.white,
        title: const Text('Оплата картой',
            style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Row(
            children: [
              Icon(Icons.lock, color: Colors.white70, size: 16),
              SizedBox(width: 6),
              Text('Защищённая оплата',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              Spacer(),
              Text('VISA  •  Mastercard',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          // Card visual
          Container(
            height: 190,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF1E5BFF), Color(0xFF0E2A47)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.credit_card, color: Colors.white, size: 32),
                const Spacer(),
                Text(_card.text,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('До оплаты  ${widget.amount} ₸',
                        style: const TextStyle(color: Colors.white70)),
                    Text(_exp.text,
                        style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _field(_card, 'Номер карты', TextInputType.number,
              [_CardFormatter()], maxLen: 19),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _field(_exp, 'ММ/ГГ', TextInputType.datetime, [])),
              const SizedBox(width: 12),
              Expanded(
                  child: _field(_cvv, 'CVV', TextInputType.number, [], maxLen: 3)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _paying ? null : _pay,
              onLongPress: null,
              child: _paying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.ink))
                  : Text('Оплатить ${widget.amount} ₸'),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('Тестовый банк (mock). Реальный банк подключается\n'
                'через тот же PaymentService.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, TextInputType kb,
      List<TextInputFormatter> fmt,
      {int? maxLen}) {
    return TextField(
      controller: c,
      keyboardType: kb,
      inputFormatters: fmt,
      maxLength: maxLen,
      style: const TextStyle(color: Colors.white),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white10,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brand, width: 2),
        ),
      ),
    );
  }
}

class _CardFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length && i < 16; i++) {
      if (i != 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return TextEditingValue(
      text: buf.toString(),
      selection: TextSelection.collapsed(offset: buf.length),
    );
  }
}
