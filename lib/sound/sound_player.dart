export 'sound_player_stub.dart'
    if (dart.library.js_interop) 'sound_player_web.dart';
    import 'package:audioplayers/audioplayers.dart';

final AudioPlayer _player = AudioPlayer();

void playSound(String type) async {
  try {
    if (type == 'start') {
      await _player.play(AssetSource('audio/start.mp3'));
    } else if (type == 'finish') {
      await _player.play(AssetSource('audio/finish.mp3'));
    } else if (type == 'achievement') {
      await _player.play(AssetSource('audio/achievement.mp3'));
    }
  } catch (e) {
    // Игнорируем ошибки, чтобы приложение не вылетало, если звука нет
  }
}