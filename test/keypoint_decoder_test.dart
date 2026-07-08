import 'package:test/test.dart';
import 'package:ugk_exercise/inference/keypoint_decoder.dart';
import 'package:ugk_exercise/pipeline/frame_pipeline.dart';

void main() {
  test('dequantizes int8 MoveNet output bytes', () {
    final values = decodeTensorValues(
      [128, 138, 127],
      type: TensorValueType.int8,
      scale: 0.1,
      zeroPoint: -128,
    );

    expect(values, [0, 1, 25.5]);
  });

  test('decodes MoveNet yx keypoints back to original pixels', () {
    final values = List<double>.filled(17 * 3, 0);
    values[0] = 0.5;
    values[1] = 0.5;
    values[2] = 0.9;

    final keypoints = decodeMoveNetKeypoints(
      values,
      LetterboxInfo.fromSize(width: 720, height: 1280, target: 192),
      width: 720,
      height: 1280,
    );

    expect(keypoints[0].x, closeTo(360, 1));
    expect(keypoints[0].y, closeTo(640, 1));
    expect(keypoints[0].confidence, closeTo(0.9, 1e-6));
  });
}
