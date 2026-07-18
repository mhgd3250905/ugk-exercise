import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ugk_exercise/platform/recognition_trace_export.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'recognition_trace_export_test_',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('returns noLogs without opening a save dialog', () async {
    var saveCalls = 0;
    final service = RecognitionTraceExportService(
      baseDir: tempDir,
      saveFile: ({required fileName, required bytes}) async {
        saveCalls++;
        return 'unused';
      },
    );

    final outcome = await service.export();

    expect(outcome, RecognitionTraceExportOutcome.noLogs);
    expect(saveCalls, 0);
  });

  test('saves ordered sessions with an export manifest', () async {
    await File(
      '${tempDir.path}${Platform.pathSeparator}'
      'recognition_20260718110000000.jsonl',
    ).writeAsString('{"type":"event","event":"first"}\n');
    await File(
      '${tempDir.path}${Platform.pathSeparator}'
      'recognition_20260718113000000.jsonl',
    ).writeAsString('{"type":"event","event":"second"}\n');
    await File(
      '${tempDir.path}${Platform.pathSeparator}ignore.txt',
    ).writeAsString('not a trace');
    String? savedName;
    Uint8List? savedBytes;
    final service = RecognitionTraceExportService(
      baseDir: tempDir,
      now: () => DateTime.utc(2026, 7, 18, 12),
      appVersionLoader: () async => '0.3.10 (13)',
      saveFile: ({required fileName, required bytes}) async {
        savedName = fileName;
        savedBytes = bytes;
        return 'content://saved-log';
      },
    );

    final outcome = await service.export();

    expect(outcome, RecognitionTraceExportOutcome.saved);
    expect(savedName, 'pushupai_recognition_logs_20260718T120000Z.jsonl');
    final lines = const LineSplitter().convert(utf8.decode(savedBytes!));
    expect(lines, hasLength(5));
    expect(jsonDecode(lines[0]), {
      'type': 'export_manifest',
      'schemaVersion': 1,
      'exportedAt': '2026-07-18T12:00:00.000Z',
      'appVersion': '0.3.10 (13)',
      'sessionCount': 2,
      'containsRawMedia': false,
    });
    expect(jsonDecode(lines[1]), {
      'type': 'session_boundary',
      'file': 'recognition_20260718110000000.jsonl',
    });
    expect(jsonDecode(lines[2]), {'type': 'event', 'event': 'first'});
    expect(jsonDecode(lines[3]), {
      'type': 'session_boundary',
      'file': 'recognition_20260718113000000.jsonl',
    });
    expect(jsonDecode(lines[4]), {'type': 'event', 'event': 'second'});
  });

  test('reports cancellation separately from save failures', () async {
    await File(
      '${tempDir.path}${Platform.pathSeparator}'
      'recognition_20260718110000000.jsonl',
    ).writeAsString('{"type":"event"}\n');
    final service = RecognitionTraceExportService(
      baseDir: tempDir,
      appVersionLoader: () async => 'test-version',
      saveFile: ({required fileName, required bytes}) async => null,
    );

    final outcome = await service.export();

    expect(outcome, RecognitionTraceExportOutcome.cancelled);
  });

  test('rejects an export larger than its memory safety limit', () async {
    await File(
      '${tempDir.path}${Platform.pathSeparator}'
      'recognition_20260718110000000.jsonl',
    ).writeAsString('${jsonEncode({'type': 'frame', 'payload': 'x' * 200})}\n');
    var saveCalls = 0;
    final service = RecognitionTraceExportService(
      baseDir: tempDir,
      maxExportBytes: 100,
      saveFile: ({required fileName, required bytes}) async {
        saveCalls++;
        return 'unused';
      },
    );

    final outcome = await service.export();

    expect(outcome, RecognitionTraceExportOutcome.tooLarge);
    expect(saveCalls, 0);
  });

  test('rejects a finalized trace with an incomplete JSON line', () async {
    await File(
      '${tempDir.path}${Platform.pathSeparator}'
      'recognition_20260718110000000.jsonl',
    ).writeAsString('{"type":"event"}\n{"type":"frame"');
    var saveCalls = 0;
    final service = RecognitionTraceExportService(
      baseDir: tempDir,
      appVersionLoader: () async => 'test-version',
      saveFile: ({required fileName, required bytes}) async {
        saveCalls++;
        return 'unused';
      },
    );

    await expectLater(service.export(), throwsFormatException);
    expect(saveCalls, 0);
  });
}
