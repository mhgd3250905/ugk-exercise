// Extracted from main.dart during architecture refactor.
//
// Top-level platform/IO helpers shared by the test-mode tabs: replay video
// resolution, keypoint log and performance-report writers, and RGB-frame
// image conversion. Pure structural move; no logic changed.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../inference/delegate_mode.dart';
import '../pipeline/frame_pipeline.dart';
import '../platform/report_directory.dart';
import '../report/performance_report.dart';
import '../ui/app_theme.dart';

Future<String> resolveReplayVideo(String? selectedPath) async {
  if (selectedPath != null && await File(selectedPath).exists()) {
    return selectedPath;
  }

  final local = File(replayVideoName);
  if (await local.exists()) {
    return local.path;
  }

  final bytes = await rootBundle.load(replayVideoName);
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, replayVideoName));
  await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  return file.path;
}

Future<File> openKeypointLog() async {
  final dir = await reportDirectory();
  return File(p.join(dir.path, 'app_keypoints.csv'));
}

Future<File> writePerformanceReport({
  required List<PerformanceSample> samples,
  required int finalCount,
  required double memoryPeakMb,
}) async {
  final totalElapsedMs = samples.fold<int>(
    0,
    (total, sample) => total + sample.e2eMs,
  );
  final report = buildPerformanceReport(
    mode: 'offline_replay',
    delegate: DelegateMode.cpu.name,
    finalCount: finalCount,
    totalElapsedMs: totalElapsedMs,
    samples: samples,
    memoryPeakMb: memoryPeakMb,
  );
  return writeJsonReport('performance_report.json', report);
}

Future<File?> writeLivePerformanceReport(
  Map<DelegateMode, List<PerformanceSample>> samplesByMode,
  Map<DelegateMode, double> memoryPeakByMode,
) async {
  final reports = [
    for (final entry in samplesByMode.entries)
      if (entry.value.isNotEmpty)
        buildPerformanceReport(
          mode: 'live_camera',
          delegate: entry.key.name,
          finalCount: 0,
          totalElapsedMs: entry.value.fold<int>(
            0,
            (total, sample) => total + sample.e2eMs,
          ),
          samples: entry.value,
          memoryPeakMb: memoryPeakByMode[entry.key] ?? 0,
        ),
  ];
  if (reports.isEmpty) {
    return null;
  }

  return writeJsonReport('live_performance_report.json', {
    'mode': 'live_camera',
    'reports': reports,
    'delegate_comparison': buildDelegateComparison(reports),
  });
}

Future<File> writeJsonReport(String name, Map<String, Object> report) async {
  final dir = await reportDirectory();
  final file = File(p.join(dir.path, name));
  const encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString(encoder.convert(report), flush: true);
  return file;
}

Future<Directory> reportDirectory() async {
  final dir = selectReportDirectory(
    external: await getExternalStorageDirectory(),
    documents: await getApplicationDocumentsDirectory(),
  );
  await dir.create(recursive: true);
  return dir;
}

double currentRssMb() {
  return ProcessInfo.currentRss / 1024 / 1024;
}

double max(double a, double b) {
  return a > b ? a : b;
}

Future<ui.Image> rgbFrameToImage(RgbFrame frame) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgbToRgba(frame.rgb),
    frame.width,
    frame.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

Uint8List rgbToRgba(Uint8List rgb) {
  final rgba = Uint8List(rgb.length ~/ 3 * 4);
  for (var i = 0, j = 0; i < rgb.length; i += 3, j += 4) {
    rgba[j] = rgb[i];
    rgba[j + 1] = rgb[i + 1];
    rgba[j + 2] = rgb[i + 2];
    rgba[j + 3] = 255;
  }
  return rgba;
}
