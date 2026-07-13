import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Debug-only JSONL sink for post-workout recognition diagnosis.
///
/// I/O failures are deliberately ignored so diagnostics can never interrupt a
/// workout. The caller controls whether logging is enabled.
class RecognitionTraceLog {
  RecognitionTraceLog({
    Directory? baseDir,
    this.enabled = true,
    this.maxFiles = 10,
  }) : _baseDir = baseDir;

  final Directory? _baseDir;
  final bool enabled;
  final int maxFiles;
  IOSink? _sink;

  Future<void> startSession(DateTime startedAt) async {
    if (!enabled) {
      return;
    }
    await close();
    try {
      final directory =
          _baseDir ??
          Directory(
            p.join(
              (await getApplicationSupportDirectory()).path,
              'recognition_traces',
            ),
          );
      await directory.create(recursive: true);
      await _removeOldFiles(directory);
      final timestamp = startedAt.toUtc().toIso8601String().replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      _sink = File(
        p.join(directory.path, 'recognition_$timestamp.jsonl'),
      ).openWrite();
    } catch (_) {
      _sink = null;
    }
  }

  void write(Map<String, Object?> record) {
    try {
      _sink?.writeln(jsonEncode(record));
    } catch (_) {
      // Diagnostics must not alter workout behavior.
    }
  }

  Future<void> close() async {
    final sink = _sink;
    _sink = null;
    if (sink == null) {
      return;
    }
    try {
      await sink.flush();
      await sink.close();
    } catch (_) {
      // Diagnostics must not alter workout behavior.
    }
  }

  Future<void> _removeOldFiles(Directory directory) async {
    final files = await directory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.jsonl'))
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    while (files.length >= maxFiles) {
      await files.removeAt(0).delete();
    }
  }
}
