import 'package:audioplayers/audioplayers.dart';

class ScanSound {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> play() async {
    try {
      await _player.stop();
      await _player.play(
        AssetSource('beep.wav'),
        volume: 0.9,
      );
    } catch (_) {}
  }
}
