import 'package:audioplayers/audioplayers.dart';

class VoicePromptPlayer {
  VoicePromptPlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  var _disposed = false;

  Future<void> playGuide() {
    return _play('audio/prompts/guide.wav');
  }

  Future<void> playReady() {
    return _play('audio/prompts/ready.wav');
  }

  Future<void> playCount(int count) async {
    if (count < 1 || count > 30) {
      return;
    }
    await _play('audio/prompts/count_${count.toString().padLeft(2, '0')}.wav');
  }

  Future<void> _play(String assetPath) async {
    if (_disposed) {
      return;
    }
    await _player.stop();
    if (_disposed) {
      return;
    }
    await _player.play(AssetSource(assetPath));
  }

  Future<void> stop() async {
    if (_disposed) {
      return;
    }
    await _player.stop();
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _player.stop();
    await _player.dispose();
  }
}
