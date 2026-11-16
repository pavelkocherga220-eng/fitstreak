import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Голосовые подсказки во время интервальной тренировки.
/// Любая ошибка (нет голоса, нет движка) гасится: тренировка идёт как обычно.
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  static const _boxName = 'fitstreak_box';
  static const _key = 'voice_enabled';

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _initTried = false;
  bool _enabled = true;
  bool _loaded = false;

  bool get enabled => _enabled;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final box = await Hive.openBox(_boxName);
      _enabled = (box.get(_key) as bool?) ?? true;
    } catch (e) {
      debugPrint('voice load error: $e');
    }
    _loaded = true;
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    if (!value) await stop();
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_key, value);
    } catch (e) {
      debugPrint('voice save error: $e');
    }
  }

  Future<void> _init() async {
    if (_initTried) return;
    _initTried = true;
    try {
      await _tts.setLanguage('ru-RU');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      _ready = true;
    } catch (e) {
      debugPrint('tts init error: $e');
    }
  }

  Future<void> speak(String text) async {
    if (!_enabled || text.trim().isEmpty) return;
    try {
      await _init();
      if (!_ready) return;
      await _tts.speak(text);
    } catch (e) {
      debugPrint('tts speak error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
