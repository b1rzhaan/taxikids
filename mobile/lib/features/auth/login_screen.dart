import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../state/auth_state.dart';
import 'driver_register_screen.dart';
import 'parent_register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().login(_email.text.trim(), _password.text);
    } catch (e) {
      setState(() => _error = ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _demo(String email, String pwd) {
    _email.text = email;
    _password.text = pwd;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset('assets/logo.png',
                      height: 84, width: 84, fit: BoxFit.cover),
                ),
                const SizedBox(height: 12),
                const Text('Детское такси',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const Text('Безопасные поездки для детей',
                    style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                              labelText: 'Email', hintText: 'parent@kids.kz'),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          decoration:
                              const InputDecoration(labelText: 'Пароль'),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!,
                              style: const TextStyle(color: AppColors.danger)),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: AppColors.ink),
                                  )
                                : const Text('Войти'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Демо-доступы:',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _demoChip('Родитель', 'parent@kids.kz', 'parent12345'),
                    _demoChip('Водитель', 'driver@kids.kz', 'driver12345'),
                  ],
                ),
                const SizedBox(height: 24),
                Divider(color: AppColors.line),
                const SizedBox(height: 12),
                const Text('Нет аккаунта? Зарегистрируйтесь',
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ParentRegisterScreen())),
                      icon: const Icon(Icons.family_restroom, size: 18),
                      label: const Text('Я родитель'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const DriverRegisterScreen())),
                      icon: const Icon(Icons.local_taxi, size: 18),
                      label: const Text('Я водитель'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _demoChip(String label, String email, String pwd) => ActionChip(
        backgroundColor: AppColors.brandSoft,
        side: BorderSide.none,
        label: Text(label),
        onPressed: () => _demo(email, pwd),
      );
}
