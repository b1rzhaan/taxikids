import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/voice.dart';
import '../../services/services.dart';
import '../../state/auth_state.dart';
import '../../widgets/profile_quick_actions.dart';
import '../../widgets/ui.dart';
import '../parent/messages_screen.dart';
import 'driver_earnings_screen.dart';
import 'driver_trips_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  Map<String, dynamic>? _me;
  bool _loading = true;
  bool _savingPhoto = false;
  int _photoVersion = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _me = await DriverService.me();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _go(Widget s) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => s));

  String _photoUrl(String raw) {
    if (raw.isEmpty || _photoVersion == 0) return raw;
    final separator = raw.contains('?') ? '&' : '?';
    return '$raw${separator}v=$_photoVersion';
  }

  Future<void> _pickPhoto() async {
    if (_savingPhoto) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      imageQuality: 86,
    );
    if (file == null) return;
    setState(() => _savingPhoto = true);
    try {
      final updated = await DriverService.updatePhoto(
        await file.readAsBytes(),
        photoName: file.name,
      );
      if (!mounted) return;
      setState(() {
        _me = {...?_me, ...updated};
        _photoVersion = DateTime.now().millisecondsSinceEpoch;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ApiClient.errorMessage(e))));
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthState>();
    final name = _me?['full_name'] as String? ?? 'Водитель';
    final photo = '${_me?['photo'] ?? ''}';
    final rating = '${_me?['rating'] ?? '—'}';
    final reviews = _me?['reviews_count'] ?? 0;
    final v = _me?['vehicle'] as Map?;
    final stats = (_me?['stats'] as Map?) ?? {};
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Center(
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          PhotoAvatar(
                            name: name,
                            photoUrl: _photoUrl(photo),
                            radius: 44,
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: GestureDetector(
                              onTap: _pickPhoto,
                              child: Container(
                                height: 32,
                                width: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.brand,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.bg,
                                    width: 3,
                                  ),
                                ),
                                child: _savingPhoto
                                    ? const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.onBrand,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.photo_camera_outlined,
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
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: AppColors.brand,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$rating · $reviews отзывов',
                              style: const TextStyle(
                                color: AppColors.brand,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                ProfileQuickActions(
                  actions: [
                    ProfileQuickAction(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Платежи',
                      onTap: () => _go(const DriverEarningsScreen()),
                    ),
                    ProfileQuickAction(
                      icon: Icons.history,
                      label: 'История',
                      onTap: () => _go(const DriverTripsScreen()),
                    ),
                    ProfileQuickAction(
                      icon: Icons.assignment_outlined,
                      label: 'Заказы',
                      onTap: () => _go(const DriverTripsScreen()),
                    ),
                    ProfileQuickAction(
                      icon: Icons.headset_mic_outlined,
                      label: 'Поддержка',
                      onTap: () => _go(const MessagesScreen(initialIndex: 1)),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _carCard(v),
                const SizedBox(height: 14),
                _statsRow(stats),
                const SizedBox(height: 14),
                _group([
                  ValueListenableBuilder<bool>(
                    valueListenable: VoiceSettings.enabled,
                    builder: (_, on, _) => SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      secondary: _leadingIcon(
                        on ? Icons.volume_up : Icons.volume_off,
                      ),
                      title: const Text(
                        'Озвучка навигатора',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      activeThumbColor: AppColors.onBrand,
                      activeTrackColor: AppColors.brand,
                      value: on,
                      onChanged: (val) => VoiceSettings.setEnabled(val),
                    ),
                  ),
                  _row(
                    Icons.info_outline,
                    'О приложении',
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Детское такси · Водитель',
                        applicationVersion: '1.0.0',
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => auth.logout(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(
                      color: AppColors.danger.withValues(alpha: 0.4),
                    ),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Выйти из аккаунта'),
                ),
              ],
            ),
    );
  }

  Widget _carCard(Map? v) {
    return GestureDetector(
      onTap: v == null ? null : () => _showCarDetails(v),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Image.asset('assets/car.png', height: 64, fit: BoxFit.contain),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Мой автомобиль',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    v != null ? '${v['make']} ${v['model']}' : 'Не указан',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  if (v != null && '${v['color'] ?? ''}'.isNotEmpty)
                    Text(
                      '${v['color']}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (v != null) ...[
              PlateBadge('${v['plate_number']}'),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ],
        ),
      ),
    );
  }

  void _showCarDetails(Map v) {
    String val(String k) {
      final x = v[k];
      return (x == null || '$x'.isEmpty) ? '—' : '$x';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Center(
              child: Image.asset(
                'assets/car.png',
                height: 92,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${v['make']} ${v['model']}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                PlateBadge('${v['plate_number']}'),
              ],
            ),
            const SizedBox(height: 16),
            _detail('Цвет', val('color')),
            _detail('Год выпуска', val('year')),
            _detail(
              'Пробег',
              v['mileage_km'] != null ? '${v['mileage_km']} км' : '—',
            ),
            _detail('Мест', val('seats')),
            _detail('Техпаспорт', val('tech_passport')),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget _statsRow(Map stats) {
    final money = '${stats['earned_month'] ?? stats['earned_week'] ?? 0}';
    return Row(
      children: [
        Expanded(
          child: StatPill(
            icon: Icons.check_circle_outline,
            value: '${stats['completed_total'] ?? 0}',
            label: 'Поездок',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatPill(
            icon: Icons.today_outlined,
            value: '${stats['trips_today'] ?? 0}',
            label: 'Сегодня',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatPill(
            icon: Icons.payments_outlined,
            value: money,
            label: '₸ мес.',
          ),
        ),
      ],
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

  Widget _row(IconData icon, String title, {VoidCallback? onTap}) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    leading: _leadingIcon(icon),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
  );
}
