import 'package:audioplayers/audioplayers.dart';

import '../config/resource_constants.dart';
import '../product/voice_prompt_player.dart';

class VoicePromptPlayer extends VoicePromptPort {
  VoicePromptPlayer({
    AudioPlayer? player,
    super.baseDir = chineseVoicePromptBaseDir,
  }) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  Future<void> _playerOperation = Future<void>.value();
  var _disposed = false;
  var _playbackGeneration = 0;

  static const _correctionThrottle = Duration(seconds: 3);
  DateTime? _lastCorrectionAt;

  @override
  Future<void> playGuide() {
    return _replacePlayback(_assetPath('guide.wav'));
  }

  @override
  Future<void> playReady() {
    return _replacePlayback(_assetPath('ready.wav'));
  }

  @override
  Future<void> playPoseLost() {
    return _replacePlayback(_assetPath('pose_lost.wav')).catchError((Object _) {
      // Optional prompts must not interrupt a workout when an asset is absent.
    });
  }

  @override
  Future<void> playTooClose() {
    return _playCorrection(_assetPath('too_close.wav'));
  }

  @override
  Future<void> playNarrowForm() {
    return _playCorrection(_assetPath('narrow_form.wav'));
  }

  @override
  Future<void> playCount(int count) {
    if (count < 1 || count > 30) {
      return Future<void>.value();
    }
    return _replacePlayback(
      _countPath(count),
      playbackRate: baseDir == englishVoicePromptBaseDir ? 1.2 : 1.0,
    );
  }

  Future<void> _playCorrection(String assetPath) {
    final now = DateTime.now();
    if (_lastCorrectionAt != null &&
        now.difference(_lastCorrectionAt!) < _correctionThrottle) {
      return Future<void>.value();
    }
    _lastCorrectionAt = now;
    return _replacePlayback(assetPath).catchError((Object _) {
      // Optional prompts must not interrupt a workout when an asset is absent.
    });
  }

  @override
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

  Future<void> _replacePlayback(String assetPath, {double playbackRate = 1.0}) {
    if (_disposed) {
      return Future<void>.value();
    }
    final generation = ++_playbackGeneration;
    final operation = _playerOperation.then((_) async {
      if (_disposed || generation != _playbackGeneration) {
        return;
      }
      await _player.stop();
      if (_disposed || generation != _playbackGeneration) {
        return;
      }
      await _player.setPlaybackRate(playbackRate);
      await _player.play(AssetSource(assetPath));
    });
    _playerOperation = operation.catchError((Object _) {});
    return operation;
  }

  String _countPath(int count) {
    return _assetPath('count_${count.toString().padLeft(2, '0')}.wav');
  }

  String _assetPath(String fileName) => '$baseDir/$fileName';

  @override
  Future<void> stop() async {
    if (_disposed) {
      return;
    }
    final generation = ++_playbackGeneration;
    final operation = _playerOperation.then((_) async {
      if (_disposed || generation != _playbackGeneration) {
        return;
      }
      await _player.stop();
    });
    _playerOperation = operation.catchError((Object _) {});
    await operation;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _playbackGeneration++;
    await _playerOperation;
    await _player.stop();
    await _player.dispose();
  }
}
