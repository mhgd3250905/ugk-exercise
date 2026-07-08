import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../pipeline/frame_pipeline.dart';

typedef FfmpegRunner = Future<String?> Function(List<String> args);

class Frame {
  const Frame({required this.index, required this.rgb});

  final int index;
  final RgbFrame rgb;

  int get width => rgb.width;
  int get height => rgb.height;
}

class VideoReplayService {
  VideoReplayService({FfmpegRunner? ffmpegRunner})
    : _ffmpegRunner = ffmpegRunner ?? _runProcessFfmpeg;

  final FfmpegRunner _ffmpegRunner;
  Directory? _tempDir;
  List<File> _frames = const [];
  var _currentIndex = 0;

  int get totalFrames => _frames.length;
  int get currentIndex => _currentIndex;

  Future<void> prepare(String videoPath) async {
    await dispose();
    final input = File(videoPath);
    if (!await input.exists()) {
      throw FileSystemException('video not found', videoPath);
    }

    _tempDir = await Directory.systemTemp.createTemp('ugk_m3_frames_');
    final outputPattern = p.join(_tempDir!.path, 'frame_%05d.ppm');
    final args = ['-y', '-i', input.path, '-vsync', '0', outputPattern];
    final error = await _ffmpegRunner(args);
    if (error != null) {
      throw StateError(error);
    }

    _frames =
        _tempDir!
            .listSync()
            .whereType<File>()
            .where((file) => p.extension(file.path).toLowerCase() == '.ppm')
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    _currentIndex = 0;

    if (_frames.isEmpty) {
      throw StateError('ffmpeg produced no frames');
    }
  }

  Future<Frame?> nextFrame() async {
    if (_currentIndex >= _frames.length) {
      return null;
    }
    final index = _currentIndex;
    final frame = decodePpmFrame(await _frames[index].readAsBytes());
    _currentIndex += 1;
    return Frame(index: index, rgb: frame);
  }

  Future<void> dispose() async {
    final dir = _tempDir;
    _tempDir = null;
    _frames = const [];
    _currentIndex = 0;
    if (dir != null && await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}

RgbFrame decodePpmFrame(Uint8List bytes) {
  var cursor = 0;

  String nextToken() {
    cursor = _skipWhitespaceAndComments(bytes, cursor);
    final start = cursor;
    while (cursor < bytes.length && !_isWhitespace(bytes[cursor])) {
      cursor += 1;
    }
    if (start == cursor) {
      throw const FormatException('unexpected end of PPM header');
    }
    return ascii.decode(bytes.sublist(start, cursor));
  }

  final magic = nextToken();
  if (magic != 'P6') {
    throw FormatException('unsupported PPM magic: $magic');
  }
  final width = int.parse(nextToken());
  final height = int.parse(nextToken());
  final maxValue = int.parse(nextToken());
  if (maxValue != 255) {
    throw FormatException('unsupported PPM max value: $maxValue');
  }

  cursor = _consumeOneHeaderSeparator(bytes, cursor);
  final expected = width * height * 3;
  if (bytes.length - cursor < expected) {
    throw FormatException('PPM payload too short: expected $expected bytes');
  }

  return RgbFrame(
    width: width,
    height: height,
    rgb: Uint8List.fromList(bytes.sublist(cursor, cursor + expected)),
  );
}

int _skipWhitespaceAndComments(Uint8List bytes, int cursor) {
  while (cursor < bytes.length) {
    if (_isWhitespace(bytes[cursor])) {
      cursor += 1;
      continue;
    }
    if (bytes[cursor] == 35) {
      while (cursor < bytes.length && bytes[cursor] != 10) {
        cursor += 1;
      }
      continue;
    }
    break;
  }
  return cursor;
}

int _consumeOneHeaderSeparator(Uint8List bytes, int cursor) {
  if (cursor + 1 < bytes.length &&
      bytes[cursor] == 13 &&
      bytes[cursor + 1] == 10) {
    return cursor + 2;
  }
  return cursor < bytes.length && _isWhitespace(bytes[cursor])
      ? cursor + 1
      : cursor;
}

bool _isWhitespace(int byte) {
  return byte == 9 ||
      byte == 10 ||
      byte == 11 ||
      byte == 12 ||
      byte == 13 ||
      byte == 32;
}

Future<String?> _runProcessFfmpeg(List<String> args) async {
  final result = await Process.run('ffmpeg', args);
  if (result.exitCode == 0) {
    return null;
  }
  return 'ffmpeg failed (${result.exitCode}): ${result.stderr}';
}
