import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/voice.dart';
import '../../state/auth_state.dart';
import '../../services/services.dart';
import 'wallet_screen.dart';
import 'children_screen.dart';
import 'history_screen.dart';
import 'messages_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = '';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await AuthService.me();
      _name = (me['full_name'] as String?) ?? '';
      _phone = (me['phone'] as String?) ?? '';
    } catch (_) {}
    if (mounted) setState(() {});
  }

  void _go(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthState>();
    final email = auth.session?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          // ── Centered identity (Yandex-style) ──
          Center(
            child: Column(
              children: [
                InitialAvatar(
                    _name.isEmpty ? (email.isEmpty ? 'Р' : email) : _name,
                    radius: 44),
                const SizedBox(height: 12),
                Text(_name.isEmpty ? 'Родитель' : _name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(_phone.isNotEmpty ? _phone : email,
                    style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          // ── Quick-action circles ──
          Row(
            children: [
              _circle(Icons.receipt_long_outlined, 'Заказы',
                  () => _go(const HistoryScreen())),
              _circle(Icons.headset_mic_outlined, 'Поддержка',
                  () => _go(const MessagesScreen(initialIndex: 1))),
              _circle(Icons.child_care_outlined, 'Дети',
                  () => _go(const ChildrenScreen())),
              _circle(Icons.account_balance_wallet_outlined, 'Кошелёк',
                  () => _go(const WalletScreen())),
            ],
          ),
          const SizedBox(height: 22),
          _group([
            _row(Icons.credit_card, 'Способы оплаты',
                subtitle: 'Карты и кошелёк',
                onTap: () => _go(const WalletScreen())),
            _row(Icons.notifications_none, 'Уведомления',
                subtitle: 'Статусы поездок',
                onTap: () => _go(const MessagesScreen())),
          ]),
          const SizedBox(height: 14),
          // Highlighted branded card
          _highlightCard(),
          const SizedBox(height: 14),
          _group([
            ValueListenableBuilder<bool>(
              valueListenable: VoiceSettings.enabled,
              builder: (_, on, _) => SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                secondary: _leadingIcon(
                    on ? Icons.volume_up : Icons.volume_off),
                title: const Text('Озвучка навигатора',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                activeThumbColor: AppColors.onBrand,
                activeTrackColor: AppColors.brand,
                value: on,
                onChanged: (v) => VoiceSettings.setEnabled(v),
              ),
            ),
            _row(Icons.info_outline, 'О приложении', onTap: _showAbout),
          ]),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => auth.logout(),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4))),
            icon: const Icon(Icons.logout),
            label: const Text('Выйти из аккаунта'),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('Детское такси · версия 1.0.0',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _circle(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              height: 58,
              width: 58,
              decoration: const BoxDecoration(
                  color: AppColors.surface, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.brand, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _highlightCard() {
    return GestureDetector(
      onTap: () => _go(const ChildrenScreen()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.brand,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          const Icon(Icons.verified_user_outlined, color: AppColors.onBrand),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Безопасность ребёнка',
                    style: TextStyle(
                        color: AppColors.onBrand,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                Text('Проверенные водители и трекинг поездки',
                    style: TextStyle(color: AppColors.onBrand, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.onBrand),
        ]),
      ),
    );
  }

  Widget _leadingIcon(IconData icon) => Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: AppColors.brand.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: AppColors.brand, size: 20),
      );

  Widget _group(List<Widget> children) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i != children.length - 1) {
        items.add(Padding(
          padding: const EdgeInsets.only(left: 64),
          child: Divider(height: 1, color: AppColors.line),
        ));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(children: items),
    );
  }

  Widget _row(IconData icon, String title,
      {String? subtitle, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: _leadingIcon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle,
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Детское такси',
      applicationVersion: '1.0.0',
      applicationLegalese: 'Безопасные поездки для детей.',
    );
  }
}
