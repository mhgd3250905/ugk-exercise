import 'package:audioplayers/audioplayers.dart';

import '../config/resource_constants.dart';

class VoicePromptPlayer {
  VoicePromptPlayer({
    AudioPlayer? player,
    this.baseDir = chineseVoicePromptBaseDir,
  }) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  final String baseDir;
  Future<void> _countPlayback = Future<void>.value();
  var _disposed = false;
  var _playbackGeneration = 0;

  Future<void> playGuide() {
    return _play(_assetPath('guide.wav'));
  }

  Future<void> playReady() {
    return _play(_assetPath('ready.wav'));
  }

  Future<void> playCount(int count) {
    if (count < 1 || count > 30) {
      return Future<void>.value();
    }
    final generation = _playbackGeneration;
    final playback = _countPlayback.then(
      (_) => _playCount(_countPath(count), generation),
    );
    _countPlayback = playback.catchError((Object _) {});
    return playback;
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
    _playbackGeneration++;
    await _player.stop();
    if (_disposed) {
      return;
    }
    await _player.play(AssetSource(assetPath));
  }

  Future<void> _playCount(String assetPath, int generation) async {
    if (_disposed || generation != _playbackGeneration) {
      return;
    }
    if (_player.state == PlayerState.playing) {
      await _player.stop();
    }
    if (_disposed || generation != _playbackGeneration) {
      return;
    }
    await _player.play(AssetSource(assetPath));
    if (_disposed || generation != _playbackGeneration) {
      return;
    }
    await _player.onPlayerStateChanged.firstWhere(
      (state) => state != PlayerState.playing,
    );
  }

  String _countPath(int count) =>
      _assetPath('count_${count.toString().padLeft(2, '0')}.wav');

  String _assetPath(String fileName) => '$baseDir/$fileName';

  Future<void> stop() async {
    if (_disposed) {
      return;
    }
    _playbackGeneration++;
    await _player.stop();
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _playbackGeneration++;
    await _player.stop();
    await _player.dispose();
  }
}
