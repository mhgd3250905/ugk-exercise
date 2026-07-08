import 'package:test/test.dart';
import 'package:ugk_exercise/pushup_domain.dart';
import 'package:ugk_exercise/product/wrist_anchor.dart';

void main() {
  test('isStable is false until calibrated', () {
    final anchor = WristAnchor();
    expect(anchor.isStable(_pose(leftWristY: 700, rightWristY: 700)), isFalse);
  });

  test('calibrate then a near-baseline frame is stable', () {
    final anchor = WristAnchor();
    anchor.calibrate(_pose(leftWristY: 700, rightWristY: 700));

    expect(anchor.isStable(_pose(leftWristY: 715, rightWristY: 690)), isTrue);
  });

  test('one wrist drifting past the margin breaks stability (AND, not averaged)',
      () {
    final anchor = WristAnchor();
    anchor.calibrate(_pose(leftWristY: 700, rightWristY: 700));

    // Left wrist rises 200px toward the face; right stays. Averaging would hide
    // this, the AND gate must catch it.
    expect(
      anchor.isStable(_pose(leftWristY: 500, rightWristY: 700)),
      isFalse,
    );
  });

  test('both wrists drifting rejects a global camera translation', () {
    final anchor = WristAnchor();
    anchor.calibrate(_pose(leftWristY: 700, rightWristY: 700));

    expect(
      anchor.isStable(_pose(leftWristY: 580, rightWristY: 580)),
      isFalse,
    );
  });

  test('a low-confidence wrist is exempt, not a dealbreaker', () {
    final anchor = WristAnchor();
    anchor.calibrate(_pose(leftWristY: 700, rightWristY: 700));

    // Right wrist invisible (floor-level support, low confidence), left holds.
    // The visible wrist is stable, so support is trustworthy.
    expect(
      anchor.isStable(
        _pose(leftWristY: 700, rightWristY: 700, rightWristConf: 0.1),
      ),
      isTrue,
    );
  });

  test('both wrists low-confidence is unknowable, so unstable', () {
    final anchor = WristAnchor();
    anchor.calibrate(_pose(leftWristY: 700, rightWristY: 700));

    expect(
      anchor.isStable(
        _pose(leftWristY: 700, rightWristY: 700, leftWristConf: 0.1, rightWristConf: 0.1),
      ),
      isFalse,
    );
  });

  test('a raised hand is high-confidence and drifts, so it still breaks', () {
    final anchor = WristAnchor();
    anchor.calibrate(_pose(leftWristY: 700, rightWristY: 700));

    // Hand raised to the face: the model sees it clearly (high conf) and it has
    // drifted 200px up. Even though the other wrist is fine, this must break.
    expect(
      anchor.isStable(_pose(leftWristY: 500, rightWristY: 700)),
      isFalse,
    );
  });

  test('reset clears the baseline so isStable is false until recalibrated', () {
    final anchor = WristAnchor();
    anchor.calibrate(_pose(leftWristY: 700, rightWristY: 700));
    expect(anchor.isCalibrated, isTrue);

    anchor.reset();
    expect(anchor.isCalibrated, isFalse);
    expect(anchor.isStable(_pose(leftWristY: 700, rightWristY: 700)), isFalse);
  });
}

List<KeyPoint> _pose({
  double leftWristY = 700,
  double rightWristY = 700,
  double leftWristConf = 0.9,
  double rightWristConf = 0.9,
}) {
  return List<KeyPoint>.generate(
    17,
    (i) => KeyPoint(index: i, x: 0, y: 0, confidence: 0.9),
  )
    ..[SignalExtractor.leftWrist] = KeyPoint(
      index: SignalExtractor.leftWrist,
      x: 100,
      y: leftWristY,
      confidence: leftWristConf,
    )
    ..[SignalExtractor.rightWrist] = KeyPoint(
      index: SignalExtractor.rightWrist,
      x: 220,
      y: rightWristY,
      confidence: rightWristConf,
    );
}
