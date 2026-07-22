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

  test('uses the reserved pose-lost prompt at normal speed', () async {
    final audioPlayer = _RecordingAudioPlayer();
    final player = VoicePromptPlayer(
      player: audioPlayer,
      baseDir: 'audio/voices/manbo/en',
    );

    await player.playPoseLost();

    expect(audioPlayer.playedPaths, ['audio/voices/manbo/en/pose_lost.wav']);
    expect(audioPlayer.playbackRates, [1.0]);
  });

  test('a missing pose-lost prompt does not fail the workout', () async {
    final player = VoicePromptPlayer(player: _FailingAudioPlayer());

    await expectLater(player.playPoseLost(), completes);
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

  test('uses 1.2x only for English count prompts', () async {
    final englishAudio = _RecordingAudioPlayer();
    final englishPlayer = VoicePromptPlayer(
      player: englishAudio,
      baseDir: 'audio/voices/manbo/en',
    );

    await englishPlayer.playCount(1);
    await englishPlayer.playReady();

    expect(englishAudio.playbackRates, [1.2, 1.0]);

    final chineseAudio = _RecordingAudioPlayer();
    final chinesePlayer = VoicePromptPlayer(player: chineseAudio);

    await chinesePlayer.playCount(1);

    expect(chineseAudio.playbackRates, [1.0]);
  });

  test('a new count interrupts the previous count without waiting', () async {
    final audioPlayer = _BlockingAudioPlayer();
    final player = VoicePromptPlayer(player: audioPlayer);
    addTearDown(player.dispose);

    unawaited(player.playCount(1));
    await _waitUntil(() => audioPlayer.playedPaths.length == 1);

    final latestStarted = player.playCount(2).then((_) => true);
    final startedWithoutWaiting = await Future.any([
      latestStarted,
      Future<bool>.delayed(const Duration(milliseconds: 100), () => false),
    ]);

    expect(startedWithoutWaiting, isTrue);
    expect(audioPlayer.playedPaths, [
      'audio/prompts/count_01.wav',
      'audio/prompts/count_02.wav',
    ]);
  });

  test('guide ready and count all use the same interrupt policy', () async {
    final audioPlayer = _BlockingAudioPlayer();
    final player = VoicePromptPlayer(player: audioPlayer);
    addTearDown(player.dispose);

    await player.playGuide();
    await player.playReady();
    await player.playCount(1);

    expect(audioPlayer.playedPaths, [
      'audio/prompts/guide.wav',
      'audio/prompts/ready.wav',
      'audio/prompts/count_01.wav',
    ]);
  });
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var i = 0; i < 100 && !predicate(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(predicate(), isTrue);
}

class _RecordingAudioPlayer extends AudioPlayer {
  final playedPaths = <String>[];
  final playbackRates = <double>[];

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
  Future<void> setPlaybackRate(double playbackRate) async {
    playbackRates.add(playbackRate);
  }

  @override
  Future<void> dispose() async {}
}

class _BlockingAudioPlayer extends _RecordingAudioPlayer {
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
    state = PlayerState.playing;
  }
}

class _FailingAudioPlayer extends _RecordingAudioPlayer {
  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) {
    return Future<void>.error(StateError('missing asset'));
  }
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
