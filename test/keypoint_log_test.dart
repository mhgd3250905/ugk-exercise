import 'package:test/test.dart';
import 'package:ugk_exercise/inference/keypoint_log.dart';
import 'package:ugk_exercise/pushup_domain.dart';

void main() {
  test('formats Step0-compatible keypoint CSV rows', () {
    final keypoints = List<KeyPoint>.generate(
      17,
      (index) => KeyPoint(
        index: index,
        x: index.toDouble(),
        y: index + 0.5,
        confidence: 0.9,
      ),
    );

    expect(
      keypointCsvHeader(),
      startsWith('frame,nose_x,nose_y,nose_conf,left_eye_x'),
    );
    expect(
      keypointCsvRow(frame: 7, keypoints: keypoints),
      startsWith('7,0.000,0.500,0.900,1.000'),
    );
  });
}
