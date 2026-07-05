                    import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/voice.dart';
import 'state/auth_state.dart';
import 'features/auth/login_screen.dart';
import 'features/parent/parent_shell.dart';
import 'features/driver/driver_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  await VoiceSettings.load();
  runApp(const KidsTransferApp());
}

class KidsTransferApp extends StatelessWidget {
  const KidsTransferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthState()..bootstrap(),
      child: MaterialApp(
        title: 'Детское такси',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    if (!auth.ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.brand)),
      );
    }
    if (!auth.isAuthed) return const LoginScreen();
    switch (auth.role) {
      case 'parent':
        return const ParentShell();
      case 'driver':
        return const DriverShell();
      default:
        return _StaffNotice(onLogout: () => auth.logout());
    }
  }
}

class _StaffNotice extends StatelessWidget {
  final VoidCallback onLogout;
  const _StaffNotice({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🖥️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text(
                'Этот аккаунт — для веб-кабинета',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Оператор, админ и бухгалтер работают через веб-кабинет на компьютере.',
                style: TextStyle(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton(onPressed: onLogout, child: const Text('Выйти')),
            ],
          ),
        ),
      ),
    );
  }
}
