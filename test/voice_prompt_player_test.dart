import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/product/voice_prompt_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AudioplayersPlatformInterface.instance = _NoopAudioplayersPlatform();
    GlobalAudioplayersPlatformInterface.instance =
        _NoopGlobalAudioplayersPlatform();
  });

  test('uses the Chinese prompt directory by default', () async {
    final audioPlayer = _RecordingAudioPlayer();
    final player = VoicePromptPlayer(player: audioPlayer);

    await player.playGuide();

    expect(audioPlayer.playedPaths, ['audio/prompts/guide.wav']);
  });

  test('uses the configured directory for ready and count prompts', () async {
    final audioPlayer = _RecordingAudioPlayer();
    final player = VoicePromptPlayer(
      player: audioPlayer,
      baseDir: 'audio/voices/manbo/en',
    );

    await player.playReady();
    await player.playCount(1);

    expect(audioPlayer.playedPaths, [
      'audio/voices/manbo/en/ready.wav',
      'audio/voices/manbo/en/count_01.wav',
    ]);
  });

  test('preloads every count prompt from the configured directory', () async {
    final audioPlayer = _RecordingAudioPlayer();
    final audioCache = _RecordingAudioCache();
    audioPlayer.audioCache = audioCache;
    final player = VoicePromptPlayer(
      player: audioPlayer,
      baseDir: 'audio/voices/manbo/en',
    );

    await player.preloadCounts();

    expect(audioCache.loadedPaths, hasLength(30));
    expect(audioCache.loadedPaths.first, 'audio/voices/manbo/en/count_01.wav');
    expect(audioCache.loadedPaths.last, 'audio/voices/manbo/en/count_30.wav');
  });
}

class _RecordingAudioPlayer extends AudioPlayer {
  final playedPaths = <String>[];

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    playedPaths.add((source as AssetSource).path);
    Timer.run(() => state = PlayerState.completed);
  }

  @override
  Future<void> stop() async {
    state = PlayerState.stopped;
  }

  @override
  Future<void> dispose() async {}
}

class _RecordingAudioCache extends AudioCache {
  final loadedPaths = <String>[];

  @override
  Future<List<Uri>> loadAll(List<String> fileNames) async {
    loadedPaths.addAll(fileNames);
    return fileNames.map((path) => Uri.parse('memory:$path')).toList();
  }
}

class _NoopAudioplayersPlatform extends AudioplayersPlatformInterface {
  final _events = <String, StreamController<AudioEvent>>{};

  @override
  Future<void> create(String playerId) async {
    _events[playerId] = StreamController<AudioEvent>.broadcast();
  }

  @override
  Stream<AudioEvent> getEventStream(String playerId) {
    return _events[playerId]!.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _NoopGlobalAudioplayersPlatform
    extends GlobalAudioplayersPlatformInterface {
  @override
  Future<void> init() async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}
