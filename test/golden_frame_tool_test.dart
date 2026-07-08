import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../tool/golden_frame_report.dart' as tool;

void main() {
  test('golden frame tool returns non-zero when gates fail', () async {
    final dir = await Directory.systemTemp.createTemp('golden_tool_test_');
    addTearDown(() => dir.delete(recursive: true));
    final app = File('${dir.path}/app.csv');
    final step0 = File('${dir.path}/step0.csv');
    final out = File('${dir.path}/report.json');
    await app.writeAsString('frame,nose_x,nose_y,nose_conf\n0,0,0,0.0\n');
    await step0.writeAsString('frame,nose_x,nose_y,nose_conf\n0,100,0,1.0\n');

    final code = await tool.runGoldenFrameReport([
      app.path,
      step0.path,
      out.path,
    ]);

    final report = jsonDecode(await out.readAsString()) as Map<String, Object?>;
    expect(code, 1);
    expect(report['pass'], isFalse);
  });

  test('golden frame tool returns zero when gates pass', () async {
    final dir = await Directory.systemTemp.createTemp('golden_tool_test_');
    addTearDown(() => dir.delete(recursive: true));
    final app = File('${dir.path}/app.csv');
    final step0 = File('${dir.path}/step0.csv');
    final out = File('${dir.path}/report.json');
    const csv = 'frame,nose_x,nose_y,nose_conf\n0,0,0,1.0\n';
    await app.writeAsString(csv);
    await step0.writeAsString(csv);

    final code = await tool.runGoldenFrameReport([
      app.path,
      step0.path,
      out.path,
    ]);

    expect(code, 0);
  });
}
