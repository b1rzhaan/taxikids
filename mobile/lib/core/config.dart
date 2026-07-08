import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class AppConfig {
  /// Production base URL, injected at build time:
  ///   flutter build apk --release --dart-define=API_BASE=https://xxx.onrender.com/api
  static const _envApi = String.fromEnvironment('API_BASE');
  static const _envWs = String.fromEnvironment('WS_BASE');

  /// Base URL of the Django API.
  ///
  /// - `--dart-define=API_BASE=...` (release / real device) wins.
  /// - Web / desktop  → localhost
  /// - Android emulator → 10.0.2.2 (host machine loopback)
  static String get apiBase {
    if (_envApi.isNotEmpty) return _envApi;
    if (kReleaseMode) return 'https://kidstransfer-api.onrender.com/api';
    if (kIsWeb) return 'http://localhost:8000/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000/api';
    } catch (_) {}
    return 'http://localhost:8000/api';
  }

  static String get wsBase {
    if (_envWs.isNotEmpty) return _envWs;
    // Derive the websocket origin from the API URL when it's provided.
    if (_envApi.isNotEmpty) {
      return _envApi
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://')
          .replaceFirst(RegExp(r'/api/?$'), '');
    }
    if (kReleaseMode) return 'wss://kidstransfer-api.onrender.com';
    if (kIsWeb) return 'ws://localhost:8000';
    try {
      if (Platform.isAndroid) return 'ws://10.0.2.2:8000';
    } catch (_) {}
    return 'ws://localhost:8000';
  }
}
