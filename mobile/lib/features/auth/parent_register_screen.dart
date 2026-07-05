import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../services/services.dart';
import '../../state/auth_state.dart';

class ParentRegisterScreen extends StatefulWidget {
  const ParentRegisterScreen({super.key});

  @override
  State<ParentRegisterScreen> createState() => _ParentRegisterScreenState();
}

class _ParentRegisterScreenState extends State<ParentRegisterScreen> {
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_fullName.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.length < 6) {
      return setState(
          () => _error = 'Заполните имя, email и пароль (мин. 6 символов)');
    }
    setState(() => _saving = true);
    try {
      final s = await AuthService.register(
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
        fullName: _fullName.text.trim(),
      );
      if (!mounted) return;
      await context.read<AuthState>().applySession(s);
    } catch (e) {
      setState(() => _error = ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация родителя')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field(_fullName, 'Ваше имя'),
          _field(_phone, 'Телефон', keyboard: TextInputType.phone),
          _field(_email, 'Email', keyboard: TextInputType.emailAddress),
          _field(_password, 'Пароль (мин. 6)', obscure: true),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
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
                          strokeWidth: 2, color: AppColors.onBrand))
                  : const Text('Создать аккаунт'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool obscure = false, TextInputType? keyboard}) {
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
}
