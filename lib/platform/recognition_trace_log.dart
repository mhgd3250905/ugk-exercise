import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opt-in JSONL sink for post-workout recognition diagnosis.
///
/// I/O failures are deliberately ignored so diagnostics can never interrupt a
/// workout. The caller controls whether logging is enabled.
class RecognitionTraceLog {
  RecognitionTraceLog({
    Directory? baseDir,
    this.enabled = true,
    this.maxFiles = 20,
    this.maxFileBytes = defaultMaxFileBytes,
    this.maxTotalBytes = defaultMaxTotalBytes,
  }) : assert(maxFiles > 0),
       assert(maxFileBytes > 0),
       assert(maxTotalBytes >= maxFileBytes),
       _baseDir = baseDir;

  static const int defaultMaxFileBytes = 12 * 1024 * 1024;
  static const int defaultMaxTotalBytes = 24 * 1024 * 1024;

  final Directory? _baseDir;
  final bool enabled;
  final int maxFiles;
  final int maxFileBytes;
  final int maxTotalBytes;
  IOSink? _sink;
  File? _activePartFile;
  File? _completedFile;
  var _writtenBytes = 0;
  var _truncated = false;

  static Future<Directory> directoryFor({Directory? baseDir}) async {
    return baseDir ??
        Directory(
          p.join(
            (await getApplicationSupportDirectory()).path,
            'recognition_traces',
          ),
        );
  }

  static Future<List<File>> sessionFiles({Directory? baseDir}) async {
    final directory = await directoryFor(baseDir: baseDir);
    if (!await directory.exists()) {
      return const [];
    }
    final files = await directory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.jsonl'))
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<void> startSession(DateTime startedAt) async {
    if (!enabled) {
      return;
    }
    await close();
    try {
      final directory = await directoryFor(baseDir: _baseDir);
      await directory.create(recursive: true);
      await _removeStalePartFiles(directory);
      await _removeOldFiles(directory);
      final timestamp = startedAt.toUtc().toIso8601String().replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      final completedFile = File(
        p.join(directory.path, 'recognition_$timestamp.jsonl'),
      );
      final partFile = File('${completedFile.path}.part');
      _completedFile = completedFile;
      _activePartFile = partFile;
      _writtenBytes = 0;
      _truncated = false;
      _sink = partFile.openWrite();
    } catch (_) {
      _sink = null;
      _activePartFile = null;
      _completedFile = null;
    }
  }

  void write(Map<String, Object?> record) {
    final sink = _sink;
    if (sink == null || _truncated) {
      return;
    }
    try {
      final recordBytes = utf8.encode('${jsonEncode(record)}\n');
      final truncatedBytes = utf8.encode(
        '${jsonEncode({'type': 'event', 'event': 'trace_truncated', 'reason': 'max_file_bytes', 'maxFileBytes': maxFileBytes})}\n',
      );
      if (_writtenBytes + recordBytes.length + truncatedBytes.length >
          maxFileBytes) {
        if (_writtenBytes + truncatedBytes.length <= maxFileBytes) {
          sink.add(truncatedBytes);
          _writtenBytes += truncatedBytes.length;
        }
        _truncated = true;
        return;
      }
      sink.add(recordBytes);
      _writtenBytes += recordBytes.length;
    } catch (_) {
      // Diagnostics must not alter workout behavior.
    }
  }

  Future<void> close() async {
    final sink = _sink;
    final partFile = _activePartFile;
    final completedFile = _completedFile;
    _sink = null;
    _activePartFile = null;
    _completedFile = null;
    if (sink == null) {
      return;
    }
    try {
      await sink.flush();
      await sink.close();
      if (partFile != null && completedFile != null) {
        await partFile.rename(completedFile.path);
      }
    } catch (_) {
      // Diagnostics must not alter workout behavior.
    }
  }

  Future<void> _removeOldFiles(Directory directory) async {
    final files = await sessionFiles(baseDir: directory);
    while (files.length >= maxFiles) {
      await files.removeAt(0).delete();
    }
    final lengths = <File, int>{};
    var totalBytes = 0;
    for (final file in files) {
      final length = await file.length();
      lengths[file] = length;
      totalBytes += length;
    }
    final existingBytesLimit = maxTotalBytes - maxFileBytes;
    while (files.isNotEmpty && totalBytes > existingBytesLimit) {
      final oldest = files.removeAt(0);
      totalBytes -= lengths[oldest]!;
      await oldest.delete();
    }
  }

  Future<void> _removeStalePartFiles(Directory directory) async {
    final files = await directory
        .list()
        .where(
          (entity) => entity is File && entity.path.endsWith('.jsonl.part'),
        )
        .cast<File>()
        .toList();
    for (final file in files) {
      await file.delete();
    }
  }
}
