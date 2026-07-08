import 'package:test/test.dart';
import 'package:ugk_exercise/product/ready_pose_gate.dart';
import 'package:ugk_exercise/pushup_domain.dart';

void main() {
  test('returns false when required keypoints are low confidence', () {
    final gate = ReadyPoseGate();
    final at = DateTime(2026, 7, 8, 10);

    expect(
      gate.update(
        keypoints: _pose(noseConf: 0.1),
        frameWidth: 720,
        frameHeight: 1280,
        at: at,
      ),
      isFalse,
    );
  });

  test('returns false while stable duration has not elapsed', () {
    final gate = ReadyPoseGate();
    final start = DateTime(2026, 7, 8, 10);

    expect(
      gate.update(
        keypoints: _pose(),
        frameWidth: 720,
        frameHeight: 1280,
        at: start,
      ),
      isFalse,
    );
    expect(
      gate.update(
        keypoints: _pose(noseX: 361, shoulderX: 359),
        frameWidth: 720,
        frameHeight: 1280,
        at: start.add(const Duration(milliseconds: 300)),
      ),
      isFalse,
    );
  });

  test('returns true after visible keypoints remain stable for 0.5s', () {
    final gate = ReadyPoseGate();
    final start = DateTime(2026, 7, 8, 10);

    gate.update(
      keypoints: _pose(),
      frameWidth: 720,
      frameHeight: 1280,
      at: start,
    );

    expect(
      gate.update(
        keypoints: _pose(noseX: 362, shoulderX: 358),
        frameWidth: 720,
        frameHeight: 1280,
        at: start.add(const Duration(milliseconds: 500)),
      ),
      isTrue,
    );
  });

  test('movement beyond jitter resets the stable timer', () {
    final gate = ReadyPoseGate();
    final start = DateTime(2026, 7, 8, 10);

    gate.update(
      keypoints: _pose(),
      frameWidth: 720,
      frameHeight: 1280,
      at: start,
    );
    gate.update(
      keypoints: _pose(noseX: 430, shoulderX: 430),
      frameWidth: 720,
      frameHeight: 1280,
      at: start.add(const Duration(milliseconds: 400)),
    );

    expect(
      gate.update(
        keypoints: _pose(noseX: 431, shoulderX: 431),
        frameWidth: 720,
        frameHeight: 1280,
        at: start.add(const Duration(milliseconds: 700)),
      ),
      isFalse,
    );
  });
}

List<KeyPoint> _pose({
  double noseX = 360,
  double noseY = 280,
  double shoulderX = 360,
  double shoulderY = 420,
  double noseConf = 0.9,
  double shoulderConf = 0.9,
}) {
  return [
    for (var i = 0; i < 17; i++)
      KeyPoint(index: i, x: 0, y: 0, confidence: 0.9),
  ]..[SignalExtractor.nose] = KeyPoint(
      index: SignalExtractor.nose,
      x: noseX,
      y: noseY,
      confidence: noseConf,
    )
    ..[SignalExtractor.leftShoulder] = KeyPoint(
      index: SignalExtractor.leftShoulder,
      x: shoulderX - 60,
      y: shoulderY,
      confidence: shoulderConf,
    )
    ..[SignalExtractor.rightShoulder] = KeyPoint(
      index: SignalExtractor.rightShoulder,
      x: shoulderX + 60,
      y: shoulderY,
      confidence: shoulderConf,
    );
}
