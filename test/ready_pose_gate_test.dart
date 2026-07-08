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

  test('returns false for upper-body selfie without full pushup keypoints', () {
    final gate = ReadyPoseGate();
    final start = DateTime(2026, 7, 8, 10);

    gate.update(
      keypoints: _pose(hipConf: 0.1),
      frameWidth: 720,
      frameHeight: 1280,
      at: start,
    );

    expect(
      gate.update(
        keypoints: _pose(hipConf: 0.1),
        frameWidth: 720,
        frameHeight: 1280,
        at: start.add(const Duration(milliseconds: 900)),
      ),
      isFalse,
    );
  });

  test('returns false when both wrists are above shoulders', () {
    final gate = ReadyPoseGate();
    final start = DateTime(2026, 7, 8, 10);

    gate.update(
      keypoints: _pose(wristY: 260),
      frameWidth: 720,
      frameHeight: 1280,
      at: start,
    );

    expect(
      gate.update(
        keypoints: _pose(wristY: 260),
        frameWidth: 720,
        frameHeight: 1280,
        at: start.add(const Duration(milliseconds: 900)),
      ),
      isFalse,
    );
  });

  test('returns false when either wrist leaves the support position', () {
    final gate = ReadyPoseGate();
    final start = DateTime(2026, 7, 8, 10);

    gate.update(
      keypoints: _pose(leftWristY: 300, rightWristY: 650),
      frameWidth: 720,
      frameHeight: 1280,
      at: start,
    );

    expect(
      gate.update(
        keypoints: _pose(leftWristY: 300, rightWristY: 650),
        frameWidth: 720,
        frameHeight: 1280,
        at: start.add(const Duration(milliseconds: 900)),
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
        at: start.add(const Duration(milliseconds: 899)),
      ),
      isFalse,
    );
    expect(
      gate.update(
        keypoints: _pose(noseX: 431, shoulderX: 431),
        frameWidth: 720,
        frameHeight: 1280,
        at: start.add(const Duration(milliseconds: 900)),
      ),
      isTrue,
    );
  });

  test('returns false when keypoints are too short', () {
    final gate = ReadyPoseGate();

    expect(
      gate.update(
        keypoints: List<KeyPoint>.generate(
          16,
          (index) => KeyPoint(index: index, x: 0, y: 0, confidence: 0.9),
        ),
        frameWidth: 720,
        frameHeight: 1280,
        at: DateTime(2026, 7, 8, 10),
      ),
      isFalse,
    );
  });

  test('returns false when frame size is invalid', () {
    final gate = ReadyPoseGate();
    final at = DateTime(2026, 7, 8, 10);

    expect(
      gate.update(keypoints: _pose(), frameWidth: 0, frameHeight: 1280, at: at),
      isFalse,
    );
    expect(
      gate.update(keypoints: _pose(), frameWidth: 720, frameHeight: -1, at: at),
      isFalse,
    );
  });

  test(
    'returns false when pose center is out of bounds and restarts timing',
    () {
      final gate = ReadyPoseGate();
      final start = DateTime(2026, 7, 8, 10);

      expect(
        gate.update(
          keypoints: _pose(noseX: 20, shoulderX: 20),
          frameWidth: 720,
          frameHeight: 1280,
          at: start,
        ),
        isFalse,
      );

      expect(
        gate.update(
          keypoints: _pose(),
          frameWidth: 720,
          frameHeight: 1280,
          at: start.add(const Duration(milliseconds: 400)),
        ),
        isFalse,
      );
      expect(
        gate.update(
          keypoints: _pose(),
          frameWidth: 720,
          frameHeight: 1280,
          at: start.add(const Duration(milliseconds: 899)),
        ),
        isFalse,
      );
      expect(
        gate.update(
          keypoints: _pose(),
          frameWidth: 720,
          frameHeight: 1280,
          at: start.add(const Duration(milliseconds: 900)),
        ),
        isTrue,
      );
    },
  );

  test('low confidence resets and requires a full stable duration again', () {
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
        keypoints: _pose(noseConf: 0.1),
        frameWidth: 720,
        frameHeight: 1280,
        at: start.add(const Duration(milliseconds: 200)),
      ),
      isFalse,
    );
    expect(
      gate.update(
        keypoints: _pose(),
        frameWidth: 720,
        frameHeight: 1280,
        at: start.add(const Duration(milliseconds: 600)),
      ),
      isFalse,
    );
    expect(
      gate.update(
        keypoints: _pose(),
        frameWidth: 720,
        frameHeight: 1280,
        at: start.add(const Duration(milliseconds: 1099)),
      ),
      isFalse,
    );
    expect(
      gate.update(
        keypoints: _pose(),
        frameWidth: 720,
        frameHeight: 1280,
        at: start.add(const Duration(milliseconds: 1100)),
      ),
      isTrue,
    );
  });
}

List<KeyPoint> _pose({
  double noseX = 360,
  double noseY = 280,
  double shoulderX = 360,
  double shoulderY = 420,
  double? wristY,
  double? leftWristY,
  double? rightWristY,
  double noseConf = 0.9,
  double shoulderConf = 0.9,
  double wristConf = 0.9,
  double hipConf = 0.9,
}) {
  return [
      for (var i = 0; i < 17; i++)
        KeyPoint(index: i, x: 0, y: 0, confidence: 0.9),
    ]
    ..[SignalExtractor.nose] = KeyPoint(
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
    )
    ..[SignalExtractor.leftWrist] = KeyPoint(
      index: SignalExtractor.leftWrist,
      x: shoulderX - 90,
      y: leftWristY ?? wristY ?? shoulderY + 220,
      confidence: wristConf,
    )
    ..[SignalExtractor.rightWrist] = KeyPoint(
      index: SignalExtractor.rightWrist,
      x: shoulderX + 90,
      y: rightWristY ?? wristY ?? shoulderY + 220,
      confidence: wristConf,
    )
    ..[SignalExtractor.leftHip] = KeyPoint(
      index: SignalExtractor.leftHip,
      x: shoulderX - 50,
      y: shoulderY + 120,
      confidence: hipConf,
    )
    ..[SignalExtractor.rightHip] = KeyPoint(
      index: SignalExtractor.rightHip,
      x: shoulderX + 50,
      y: shoulderY + 120,
      confidence: hipConf,
    );
}
