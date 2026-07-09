import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../services/services.dart';
import '../../state/auth_state.dart';

class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  final _iin = TextEditingController();
  final _phone = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _color = TextEditingController();
  final _mileage = TextEditingController();
  final _plate = TextEditingController();

  Uint8List? _carPhoto, _licensePhoto, _idPhoto;
  bool _saving = false;
  String? _error;

  Future<Uint8List?> _pick() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      imageQuality: 85,
    );
    return x?.readAsBytes();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_email.text.trim().isEmpty || _password.text.length < 6) {
      return setState(
        () => _error = 'Укажите email и пароль (мин. 6 символов)',
      );
    }
    if (_fullName.text.trim().isEmpty || _iin.text.trim().isEmpty) {
      return setState(() => _error = 'Укажите ФИО и ИИН');
    }
    if (_make.text.trim().isEmpty || _plate.text.trim().isEmpty) {
      return setState(() => _error = 'Укажите марку и госномер авто');
    }
    if (_carPhoto == null || _licensePhoto == null || _idPhoto == null) {
      return setState(
        () => _error = 'Загрузите фото авто, прав и удостоверения',
      );
    }
    setState(() => _saving = true);
    try {
      final s = await AuthService.registerDriver(
        email: _email.text.trim(),
        password: _password.text,
        fullName: _fullName.text.trim(),
        iin: _iin.text.trim(),
        phone: _phone.text.trim(),
        carMake: _make.text.trim(),
        carModel: _model.text.trim(),
        carColor: _color.text.trim(),
        carMileage: int.tryParse(_mileage.text.trim()),
        carPlate: _plate.text.trim(),
        carPhoto: _carPhoto,
        licensePhoto: _licensePhoto,
        idCardPhoto: _idPhoto,
      );
      if (!mounted) return;
      await context.read<AuthState>().applySession(s);
      // AuthState notifies → _Root rebuilds into the (pending) driver app.
    } catch (e) {
      setState(() => _error = ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Стать водителем')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('1. Аккаунт'),
          _field(_email, 'Email', keyboard: TextInputType.emailAddress),
          _field(_password, 'Пароль (мин. 6)', obscure: true),
          _field(_fullName, 'ФИО'),
          _field(_iin, 'ИИН', keyboard: TextInputType.number),
          _field(_phone, 'Телефон', keyboard: TextInputType.phone),
          const SizedBox(height: 20),
          _section('2. Автомобиль'),
          Row(
            children: [
              Expanded(child: _field(_make, 'Марка')),
              const SizedBox(width: 10),
              Expanded(child: _field(_model, 'Модель')),
            ],
          ),
          Row(
            children: [
              Expanded(child: _field(_color, 'Цвет')),
              const SizedBox(width: 10),
              Expanded(
                child: _field(
                  _mileage,
                  'Пробег, км',
                  keyboard: TextInputType.number,
                ),
              ),
            ],
          ),
          _field(_plate, 'Госномер'),
          const SizedBox(height: 20),
          _section('3. Документы'),
          const Text(
            'Загрузите чёткие фото — оператор проверит заявку.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _photoTile(
            'Фото автомобиля',
            Icons.directions_car,
            _carPhoto,
            () async {
              final b = await _pick();
              if (b != null) setState(() => _carPhoto = b);
            },
          ),
          _photoTile(
            'Водительское удостоверение',
            Icons.badge_outlined,
            _licensePhoto,
            () async {
              final b = await _pick();
              if (b != null) setState(() => _licensePhoto = b);
            },
          ),
          _photoTile(
            'Удостоверение личности',
            Icons.perm_identity,
            _idPhoto,
            () async {
              final b = await _pick();
              if (b != null) setState(() => _idPhoto = b);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.brand, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'После отправки заявка уйдёт на проверку оператору. '
                    'Войти можно сразу, но заказы станут доступны после одобрения.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onBrand,
                      ),
                    )
                  : const Text('Отправить заявку'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      t,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    ),
  );

  Widget _field(
    TextEditingController c,
    String label, {
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: obscure,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _photoTile(
    String label,
    IconData icon,
    Uint8List? bytes,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: bytes != null
                  ? AppColors.brand.withValues(alpha: 0.6)
                  : AppColors.line,
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  image: bytes != null
                      ? DecorationImage(
                          image: MemoryImage(bytes),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: bytes == null
                    ? Icon(icon, color: AppColors.muted, size: 24)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Icon(
                bytes != null ? Icons.check_circle : Icons.upload_outlined,
                color: bytes != null ? AppColors.success : AppColors.brand,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
