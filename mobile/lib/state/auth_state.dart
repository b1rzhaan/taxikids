import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/auth_store.dart';
import '../models/models.dart';
import '../services/services.dart';

class AuthState extends ChangeNotifier {
  Session? _session;
  bool _ready = false;

  Session? get session => _session;
  bool get ready => _ready;
  bool get isAuthed => _session != null;
  String get role => _session?.role ?? '';

  Future<void> bootstrap() async {
    _session = await AuthStore.load();
    ApiClient.instance.setSession(_session);
    _ready = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final s = await AuthService.login(email, password);
    await _apply(s);
  }

  Future<void> register({
    required String email,
    required String phone,
    required String password,
    required String fullName,
  }) async {
    final s = await AuthService.register(
      email: email,
      phone: phone,
      password: password,
      fullName: fullName,
    );
    await _apply(s);
  }

  /// Apply an externally-obtained session (e.g. after driver registration).
  Future<void> applySession(Session s) => _apply(s);

  Future<void> _apply(Session s) async {
    _session = s;
    ApiClient.instance.setSession(s);
    await AuthStore.save(s);
    notifyListeners();
  }

  Future<void> logout() async {
    _session = null;
    ApiClient.instance.setSession(null);
    await AuthStore.clear();
    notifyListeners();
  }
}
