import 'dart:convert';
import 'dart:io';

import 'package:ugk_exercise/report/golden_frame_report.dart';

Future<void> main(List<String> args) async {
  exitCode = await runGoldenFrameReport(args);
}

Future<int> runGoldenFrameReport(List<String> args) async {
  final appPath = args.isNotEmpty ? args[0] : 'app_keypoints.csv';
  final step0Path = args.length > 1 ? args[1] : 'step0/out_signals.csv';
  final outPath = args.length > 2 ? args[2] : 'golden_frame_report.json';

  final report = buildGoldenFrameReport(
    appCsv: await File(appPath).readAsString(),
    step0Csv: await File(step0Path).readAsString(),
  );
  final outFile = File(outPath);
  await outFile.parent.create(recursive: true);
  await outFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(report),
  );
  stdout.writeln(outPath);
  return report['pass'] == true ? 0 : 1;
}
