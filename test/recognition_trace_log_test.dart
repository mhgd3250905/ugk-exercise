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
}
