import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

void main() {
  test('count prompts begin audibly within 50 ms', () {
    for (var count = 1; count <= 30; count++) {
      final name = 'count_${count.toString().padLeft(2, '0')}.wav';
      final canonical = File(
        'assets/audio/voices/manbo/zh/$name',
      ).readAsBytesSync();
      final prompt = File('assets/audio/prompts/$name').readAsBytesSync();
      final wav = _readPcm16Wav(prompt);

      expect(prompt, canonical, reason: '$name must match the source theme');
      expect(
        _audibleOnset(wav),
        lessThanOrEqualTo(const Duration(milliseconds: 50)),
        reason: '$name has too much leading silence',
      );
    }
  });

  test('count prompts keep at least 80 ms after the final audible sample', () {
    for (var count = 1; count <= 30; count++) {
      final name = 'count_${count.toString().padLeft(2, '0')}.wav';
      final wav = _readPcm16Wav(
        File('assets/audio/prompts/$name').readAsBytesSync(),
      );

      expect(
        _trailingQuiet(wav),
        greaterThanOrEqualTo(const Duration(milliseconds: 80)),
        reason: '$name ends too close to the final audible sample',
      );
    }
  });

  test('count prompts preload when a workout starts', () {
    final player = File(
      'lib/product/voice_prompt_player.dart',
    ).readAsStringSync();
    final controller = File(
      'lib/control/workout_controller.dart',
    ).readAsStringSync();

    expect(player, contains('Future<void> preloadCounts()'));
    expect(player, contains('_player.audioCache.loadAll'));
    expect(controller, contains('unawaited(_voice.preloadCounts());'));
  });

  test('count prompts wait for the previous count to finish', () {
    final player = File(
      'lib/product/voice_prompt_player.dart',
    ).readAsStringSync();

    expect(player, contains('_countPlayback'));
    expect(player, contains('_player.onPlayerStateChanged.firstWhere'));
  });
}

({ByteData data, int offset, int samples, int sampleRate}) _readPcm16Wav(
  Uint8List bytes,
) {
  final data = ByteData.sublistView(bytes);
  expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
  expect(ascii.decode(bytes.sublist(8, 12)), 'WAVE');

  int? sampleRate;
  int? dataOffset;
  int? dataLength;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = ascii.decode(bytes.sublist(offset, offset + 4));
    final length = data.getUint32(offset + 4, Endian.little);
    final payload = offset + 8;
    if (id == 'fmt ') {
      expect(data.getUint16(payload, Endian.little), 1);
      expect(data.getUint16(payload + 2, Endian.little), 1);
      sampleRate = data.getUint32(payload + 4, Endian.little);
      expect(data.getUint16(payload + 14, Endian.little), 16);
    } else if (id == 'data') {
      dataOffset = payload;
      dataLength = length;
    }
    offset = payload + length + (length.isOdd ? 1 : 0);
  }

  expect(sampleRate, isNotNull);
  expect(dataOffset, isNotNull);
  expect(dataLength, isNotNull);
  return (
    data: data,
    offset: dataOffset!,
    samples: dataLength! ~/ 2,
    sampleRate: sampleRate!,
  );
}

Duration _audibleOnset(
  ({ByteData data, int offset, int samples, int sampleRate}) wav,
) {
  const threshold = 328; // -40 dBFS for signed 16-bit PCM.
  final window = wav.sampleRate ~/ 50; // 20 ms.
  final required = wav.sampleRate ~/ 200; // 5 ms above threshold.
  var hits = 0;
  for (var i = 0; i < wav.samples; i++) {
    final sample = wav.data.getInt16(wav.offset + i * 2, Endian.little);
    if (sample.abs() >= threshold) {
      hits++;
    }
    if (i >= window) {
      final old = wav.data.getInt16(
        wav.offset + (i - window) * 2,
        Endian.little,
      );
      if (old.abs() >= threshold) {
        hits--;
      }
    }
    if (i >= window - 1 && hits >= required) {
      final onsetSample = i - window + 1;
      return Duration(
        microseconds:
            (onsetSample * Duration.microsecondsPerSecond) ~/ wav.sampleRate,
      );
    }
  }
  return const Duration(days: 1);
}

Duration _trailingQuiet(
  ({ByteData data, int offset, int samples, int sampleRate}) wav,
) {
  const threshold = 328; // -40 dBFS for signed 16-bit PCM.
  for (var i = wav.samples - 1; i >= 0; i--) {
    final sample = wav.data.getInt16(wav.offset + i * 2, Endian.little);
    if (sample.abs() >= threshold) {
      final quietSamples = wav.samples - i - 1;
      return Duration(
        microseconds:
            (quietSamples * Duration.microsecondsPerSecond) ~/ wav.sampleRate,
      );
    }
  }
  return Duration(
    microseconds:
        (wav.samples * Duration.microsecondsPerSecond) ~/ wav.sampleRate,
  );
}
