import 'package:flutter/foundation.dart';

class AppConfig {
  static const _productionApi = 'https://kidstransfer-api.onrender.com/api';
  static const _productionWs = 'wss://kidstransfer-api.onrender.com';

  /// Production base URL, injected at build time:
  ///   flutter build apk --release --dart-define=API_BASE=https://xxx.onrender.com/api
  static const _envApi = String.fromEnvironment('API_BASE');
  static const _envWs = String.fromEnvironment('WS_BASE');

  /// Base URL of the Django API.
  ///
  /// - `--dart-define=API_BASE=...` wins for local/dev overrides.
  /// - Otherwise use the deployed API even in debug builds, so emulator and
  ///   real-phone testing don't silently point to 10.0.2.2.
  static String get apiBase {
    if (_envApi.isNotEmpty) return _envApi;
    if (kIsWeb && kDebugMode) return 'http://localhost:8000/api';
    return _productionApi;
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
    if (kIsWeb && kDebugMode) return 'ws://localhost:8000';
    return _productionWs;
  }
}
