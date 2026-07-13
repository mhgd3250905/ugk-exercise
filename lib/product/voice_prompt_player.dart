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
    await _play(_countPath(count));
  }

  Future<void> preloadCounts() async {
    if (_disposed) {
      return;
    }
    try {
      await _player.audioCache.loadAll([
        for (var count = 1; count <= 30; count++) _countPath(count),
      ]);
    } catch (_) {
      // Playback still falls back to loading the requested asset on demand.
    }
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

  static String _countPath(int count) =>
      'audio/prompts/count_${count.toString().padLeft(2, '0')}.wav';

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
