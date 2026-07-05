import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Voice guidance settings + TTS engine for the navigator.
class VoiceSettings {
  static const _key = 'kt_voice_enabled';
  static final ValueNotifier<bool> enabled = ValueNotifier(true);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool(_key) ?? true;
  }

  static Future<void> setEnabled(bool v) async {
    enabled.value = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, v);
    if (!v) Speaker.stop();
  }
}

class Speaker {
  static final FlutterTts _tts = FlutterTts();
  static bool _ready = false;

  static Future<void> _init() async {
    if (_ready) return;
    try {
      await _tts.setLanguage('ru-RU');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (_) {}
    _ready = true;
  }

  static Future<void> say(String text) async {
    if (!VoiceSettings.enabled.value || text.trim().isEmpty) return;
    await _init();
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
