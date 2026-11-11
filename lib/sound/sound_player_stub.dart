import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

// Создаем отдельные плееры, чтобы звуки не прерывали друг друга
final AudioPlayer _playerFinish = AudioPlayer();
final AudioPlayer _playerAchievement = AudioPlayer();
final AudioPlayer _playerCountdown = AudioPlayer();
final AudioPlayer _playerBeep = AudioPlayer();

void playSound(String type) async {
  try {
    debugPrint('▶️ just_audio: $type');
    
    if (type == 'finish') {
      await _playerFinish.setAsset('assets/audio/finish.mp3');
      _playerFinish.play();
    } else if (type == 'achievement') {
      await _playerAchievement.setAsset('assets/audio/achievement.mp3');
      _playerAchievement.play();
    } else if (type == 'countdown') {
      await _playerCountdown.setAsset('assets/audio/countdown.mp3');
      _playerCountdown.play();
    } else if (type == 'beep') {
      await _playerBeep.setAsset('assets/audio/beep.mp3');
      _playerBeep.play();
    }
  } catch (e) {
    debugPrint('🔴 Ошибка just_audio ($type): $e');
  }
}