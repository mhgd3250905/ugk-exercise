import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:ugk_exercise/platform/recognition_trace_log.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('recognition_trace_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('writes parseable JSONL records', () async {
    final log = RecognitionTraceLog(baseDir: tempDir);

    await log.startSession(DateTime.utc(2026, 7, 13, 10));
    log.write({'type': 'frame', 'count': 1});
    await log.close();

    final files = await tempDir
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    expect(files, hasLength(1));
    final lines = await files.single.readAsLines();
    expect(jsonDecode(lines.single), {'type': 'frame', 'count': 1});
  });

  test('disabled logger creates no files', () async {
    final log = RecognitionTraceLog(baseDir: tempDir, enabled: false);

    await log.startSession(DateTime.utc(2026, 7, 13, 10));
    log.write({'type': 'frame'});
    await log.close();

    expect(await tempDir.list().toList(), isEmpty);
  });

  test('retains only the newest session files', () async {
    final log = RecognitionTraceLog(baseDir: tempDir, maxFiles: 2);

    for (var hour = 10; hour < 13; hour++) {
      await log.startSession(DateTime.utc(2026, 7, 13, hour));
      log.write({'hour': hour});
      await log.close();
    }

    final files = await tempDir
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    expect(files, hasLength(2));
    expect(await files.first.readAsString(), contains('"hour":11'));
    expect(await files.last.readAsString(), contains('"hour":12'));
  });

  test('retains the newest twenty sessions by default', () async {
    final log = RecognitionTraceLog(baseDir: tempDir);

    for (var minute = 0; minute < 21; minute++) {
      await log.startSession(DateTime.utc(2026, 7, 13, 10, minute));
      log.write({'minute': minute});
      await log.close();
    }

    final files = await tempDir
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    expect(files, hasLength(20));
    expect(await files.first.readAsString(), contains('"minute":1'));
    expect(await files.last.readAsString(), contains('"minute":20'));
  });

  test('exposes a session only after close finalizes it', () async {
    final log = RecognitionTraceLog(baseDir: tempDir);

    await log.startSession(DateTime.utc(2026, 7, 13, 10));
    log.write({'type': 'frame', 'count': 1});

    expect(await RecognitionTraceLog.sessionFiles(baseDir: tempDir), isEmpty);
    final activeFiles = await tempDir
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    expect(activeFiles.single.path, endsWith('.jsonl.part'));

    await log.close();

    final completed = await RecognitionTraceLog.sessionFiles(baseDir: tempDir);
    expect(completed, hasLength(1));
    expect(completed.single.path, endsWith('.jsonl'));
  });

  test('caps one session with a valid truncation record', () async {
    final log = RecognitionTraceLog(
      baseDir: tempDir,
      maxFileBytes: 240,
      maxTotalBytes: 480,
    );

    await log.startSession(DateTime.utc(2026, 7, 13, 10));
    for (var index = 0; index < 20; index++) {
      log.write({'type': 'frame', 'index': index, 'payload': 'x' * 80});
    }
    await log.close();

    final file = (await RecognitionTraceLog.sessionFiles(
      baseDir: tempDir,
    )).single;
    expect(await file.length(), lessThanOrEqualTo(240));
    final records = [
      for (final line in await file.readAsLines())
        jsonDecode(line) as Map<String, Object?>,
    ];
    expect(records.last['event'], 'trace_truncated');
    expect(records.last['maxFileBytes'], 240);
  });

  test(
    'bounds total completed trace storage while keeping the newest',
    () async {
      final log = RecognitionTraceLog(
        baseDir: tempDir,
        maxFileBytes: 200,
        maxTotalBytes: 400,
      );

      for (var minute = 0; minute < 5; minute++) {
        await log.startSession(DateTime.utc(2026, 7, 13, 10, minute));
        log.write({'minute': minute, 'payload': 'x' * 50});
        await log.close();
      }

      final files = await RecognitionTraceLog.sessionFiles(baseDir: tempDir);
      final totalBytes = (await Future.wait(
        files.map((file) => file.length()),
      )).fold<int>(0, (total, length) => total + length);
      expect(totalBytes, lessThanOrEqualTo(400));
      expect(await files.last.readAsString(), contains('"minute":4'));
    },
  );
}
