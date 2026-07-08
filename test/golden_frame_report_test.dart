import 'package:test/test.dart';
import 'package:ugk_exercise/report/golden_frame_report.dart';

void main() {
  test('compares app keypoints against Step0 CSV gates', () {
    const appCsv = '''
frame,nose_x,nose_y,nose_conf,left_eye_x,left_eye_y,left_eye_conf
0,10,20,0.9,30,40,0.8
1,12,22,0.7,32,42,0.6
''';
    const step0Csv = '''
frame,nose_x,nose_y,nose_conf,left_eye_x,left_eye_y,left_eye_conf
0,11,20,0.8,30,43,0.7
1,16,22,0.6,40,42,0.5
''';

    final report = buildGoldenFrameReport(appCsv: appCsv, step0Csv: step0Csv);

    expect(report['frames'], 2);
    expect(report['points'], 4);
    expect(report['coord_median_px'], 3);
    expect(report['coord_p95_px'], 8);
    expect(report['conf_mean_abs_diff'], closeTo(0.1, 1e-9));
    expect(report['pass'], isTrue);
  });

  test('includes per-frame per-keypoint diffs', () {
    const appCsv = '''
frame,nose_x,nose_y,nose_conf
7,10,20,0.9
''';
    const step0Csv = '''
frame,nose_x,nose_y,nose_conf
7,13,24,0.7
''';

    final report = buildGoldenFrameReport(appCsv: appCsv, step0Csv: step0Csv);

    expect(report['details'], [
      {
        'frame': 7,
        'keypoint': 'nose',
        'coord_diff_px': 5.0,
        'conf_abs_diff': closeTo(0.2, 1e-9),
      },
    ]);
  });
}
