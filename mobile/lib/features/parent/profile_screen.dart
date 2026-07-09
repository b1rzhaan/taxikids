import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../state/auth_state.dart';
import '../../services/services.dart';
import '../../widgets/profile_quick_actions.dart';
import 'wallet_screen.dart';
import 'children_screen.dart';
import 'history_screen.dart';
import 'messages_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onProfileChanged;

  const ProfileScreen({super.key, this.onProfileChanged});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = '';
  String _phone = '';
  String _photo = '';
  bool _saving = false;

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
      _photo = (me['photo'] as String?) ?? '';
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
          Center(child: _identity(email)),
          const SizedBox(height: 22),
          ProfileQuickActions(
            actions: [
              ProfileQuickAction(
                icon: Icons.receipt_long_outlined,
                label: 'Заказы',
                onTap: () => _go(const HistoryScreen()),
              ),
              ProfileQuickAction(
                icon: Icons.headset_mic_outlined,
                label: 'Поддержка',
                onTap: () => _go(const MessagesScreen(initialIndex: 1)),
              ),
              ProfileQuickAction(
                icon: Icons.child_care_outlined,
                label: 'Дети',
                onTap: () => _go(const ChildrenScreen()),
              ),
              ProfileQuickAction(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Кошелёк',
                onTap: () => _go(const WalletScreen()),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _group([
            _row(
              Icons.credit_card,
              'Способы оплаты',
              subtitle: 'Карты и кошелёк',
              onTap: () => _go(const WalletScreen()),
            ),
            _row(
              Icons.notifications_none,
              'Уведомления',
              subtitle: 'Статусы поездок',
              onTap: () => _go(const MessagesScreen()),
            ),
          ]),
          const SizedBox(height: 14),
          // Highlighted branded card
          _highlightCard(),
          const SizedBox(height: 14),
          _group([_row(Icons.info_outline, 'О приложении', onTap: _showAbout)]),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => auth.logout(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Выйти из аккаунта'),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Детское такси · версия 1.0.0',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _identity(String email) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _profileAvatar(email, radius: 44),
            Positioned(
              right: -2,
              bottom: -2,
              child: GestureDetector(
                onTap: _openEdit,
                child: Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bg, width: 3),
                  ),
                  child: const Icon(
                    Icons.edit,
                    color: AppColors.onBrand,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _name.isEmpty ? 'Родитель' : _name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          _phone.isNotEmpty ? _phone : email,
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _saving ? null : _openEdit,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Редактировать'),
        ),
      ],
    );
  }

  Widget _profileAvatar(String email, {required double radius}) {
    if (_photo.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(_photo),
      );
    }
    return InitialAvatar(
      _name.isEmpty ? (email.isEmpty ? 'Р' : email) : _name,
      radius: radius,
    );
  }

  Future<void> _openEdit() async {
    final name = TextEditingController(text: _name);
    final phone = TextEditingController(text: _phone);
    Uint8List? pickedBytes;
    String pickedName = 'profile.jpg';
    String? error;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> pickPhoto() async {
            final file = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 900,
              imageQuality: 86,
            );
            if (file == null) return;
            pickedBytes = await file.readAsBytes();
            pickedName = file.name;
            setSheetState(() {});
          }

          Future<void> save() async {
            if (name.text.trim().isEmpty) {
              setSheetState(() => error = 'Укажите имя');
              return;
            }
            setSheetState(() => error = null);
            setState(() => _saving = true);
            try {
              await AuthService.updateMe(
                fullName: name.text.trim(),
                phone: phone.text.trim(),
                photo: pickedBytes,
                photoName: pickedName,
              );
              if (context.mounted) Navigator.pop(context, true);
            } catch (e) {
              setSheetState(() => error = ApiClient.errorMessage(e));
            } finally {
              if (mounted) setState(() => _saving = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: AppColors.line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Text(
                        'Редактировать профиль',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: pickPhoto,
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: AppColors.brandSoft,
                          backgroundImage: pickedBytes != null
                              ? MemoryImage(pickedBytes!)
                              : (_photo.isNotEmpty
                                        ? NetworkImage(_photo)
                                        : null)
                                    as ImageProvider?,
                          child: pickedBytes == null && _photo.isEmpty
                              ? const Icon(
                                  Icons.photo_camera_outlined,
                                  color: AppColors.onBrand,
                                  size: 28,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: pickPhoto,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Выбрать фото'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: name,
                        decoration: const InputDecoration(labelText: 'Имя'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Телефон'),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _saving ? null : save,
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.onBrand,
                                  ),
                                )
                              : const Text('Сохранить'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    if (saved == true) {
      await _load();
      widget.onProfileChanged?.call();
    }
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
        child: Row(
          children: [
            const Icon(Icons.verified_user_outlined, color: AppColors.onBrand),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Безопасность ребёнка',
                    style: TextStyle(
                      color: AppColors.onBrand,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Проверенные водители и трекинг поездки',
                    style: TextStyle(color: AppColors.onBrand, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.onBrand),
          ],
        ),
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
        items.add(
          Padding(
            padding: const EdgeInsets.only(left: 64),
            child: Divider(height: 1, color: AppColors.line),
          ),
        );
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

  Widget _row(
    IconData icon,
    String title, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: _leadingIcon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
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
