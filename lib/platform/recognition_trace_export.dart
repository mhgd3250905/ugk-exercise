import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import 'app_version_service.dart';
import 'recognition_trace_log.dart';

enum RecognitionTraceExportOutcome { saved, cancelled, noLogs, tooLarge }

typedef RecognitionTraceSaveFile =
    Future<String?> Function({
      required String fileName,
      required Uint8List bytes,
    });

class RecognitionTraceExportService {
  RecognitionTraceExportService({
    Directory? baseDir,
    DateTime Function()? now,
    Future<String> Function()? appVersionLoader,
    RecognitionTraceSaveFile? saveFile,
    this.maxExportBytes = 25 * 1024 * 1024,
  }) : _baseDir = baseDir,
       _now = now,
       _appVersionLoader = appVersionLoader,
       _saveFile = saveFile,
       assert(maxExportBytes > 0);

  final Directory? _baseDir;
  final DateTime Function()? _now;
  final Future<String> Function()? _appVersionLoader;
  final RecognitionTraceSaveFile? _saveFile;
  final int maxExportBytes;

  Future<RecognitionTraceExportOutcome> export() async {
    final files = await RecognitionTraceLog.sessionFiles(baseDir: _baseDir);
    if (files.isEmpty) {
      return RecognitionTraceExportOutcome.noLogs;
    }

    var traceBytes = 0;
    for (final file in files) {
      traceBytes += await file.length();
      if (traceBytes > maxExportBytes) {
        return RecognitionTraceExportOutcome.tooLarge;
      }
    }

    final exportedAt = (_now?.call() ?? DateTime.now()).toUtc();
    final appVersion =
        await (_appVersionLoader?.call() ??
            const AppVersionService().installedVersion());
    final manifestBytes = _jsonLine({
      'type': 'export_manifest',
      'schemaVersion': 1,
      'exportedAt': exportedAt.toIso8601String(),
      'appVersion': appVersion,
      'sessionCount': files.length,
      'containsRawMedia': false,
    });
    final boundaryBytes = [
      for (final file in files)
        _jsonLine({'type': 'session_boundary', 'file': p.basename(file.path)}),
    ];
    final expectedBytes =
        traceBytes +
        manifestBytes.length +
        boundaryBytes.fold<int>(0, (total, bytes) => total + bytes.length);
    if (expectedBytes > maxExportBytes) {
      return RecognitionTraceExportOutcome.tooLarge;
    }
    final bytes = BytesBuilder(copy: false)..add(manifestBytes);

    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      bytes.add(boundaryBytes[index]);
      final contents = await file.readAsBytes();
      _validateJsonl(contents, file.path);
      bytes.add(contents);
    }

    final fileName =
        'pushupai_recognition_logs_${_fileTimestamp(exportedAt)}.jsonl';
    final saveFile = _saveFile;
    final savedPath = saveFile != null
        ? await saveFile(fileName: fileName, bytes: bytes.takeBytes())
        : await FilePicker.saveFile(
            fileName: fileName,
            type: FileType.custom,
            allowedExtensions: const ['jsonl'],
            bytes: bytes.takeBytes(),
          );
    return savedPath == null
        ? RecognitionTraceExportOutcome.cancelled
        : RecognitionTraceExportOutcome.saved;
  }

  Uint8List _jsonLine(Map<String, Object?> value) =>
      Uint8List.fromList(utf8.encode('${jsonEncode(value)}\n'));

  void _validateJsonl(Uint8List contents, String path) {
    if (contents.isEmpty) {
      return;
    }
    if (contents.last != 0x0a) {
      throw FormatException('Incomplete JSONL file: $path');
    }
    final lines = const LineSplitter().convert(utf8.decode(contents));
    for (final line in lines) {
      if (jsonDecode(line) is! Map) {
        throw FormatException('Non-object JSONL record: $path');
      }
    }
  }

  String _fileTimestamp(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}'
        '${twoDigits(value.month)}${twoDigits(value.day)}T'
        '${twoDigits(value.hour)}${twoDigits(value.minute)}'
        '${twoDigits(value.second)}Z';
  }
}
