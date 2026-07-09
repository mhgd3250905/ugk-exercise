import 'package:test/test.dart';
import 'package:ugk_exercise/product/pushup_pipeline.dart';
import 'package:ugk_exercise/pushup_domain.dart';

/// Verifies the pipeline assembly (extractor → filter → counter) produces the
/// same results as the hand-written chain it replaces, and that the wrist
/// gate (passed in as handsStable) actually blocks counting.
void main() {
  test('counts synthetic reps through the assembled pipeline', () {
    final pipeline = PushupPipeline();
    CounterState state = const CounterState.initial();

    final ys = <double>[
      for (var r = 0; r < 3; r++) ...[
        for (var i = 0; i < 10; i++) 100,
        for (var i = 0; i < 10; i++) 200,
      ],
    ];
    for (final y in ys) {
      state = pipeline.process(_keypoints(y));
    }

    expect(state.count, 3);
  });

  test('handsStable=false freezes the count', () {
    final pipeline = PushupPipeline();

    // Count two reps with stable hands.
    for (final y in [
      for (var r = 0; r < 2; r++) ...[
        for (var i = 0; i < 10; i++) 100.0,
        for (var i = 0; i < 10; i++) 200.0,
      ],
    ]) {
      pipeline.process(_keypoints(y), handsStable: true);
    }
    expect(pipeline.count, 2);

    // Same motion but hands flagged unstable: must not advance.
    for (final y in [for (var i = 0; i < 20; i++) 150.0]) {
      pipeline.process(_keypoints(y), handsStable: false);
    }
    expect(pipeline.count, 2);
  });

  test('reset clears the count for a fresh session', () {
    final pipeline = PushupPipeline();
    for (final y in [
      for (var i = 0; i < 20; i++) 100.0,
      for (var i = 0; i < 20; i++) 200.0,
    ]) {
      pipeline.process(_keypoints(y));
    }
    expect(pipeline.count, 1);

    pipeline.reset();
    expect(pipeline.count, 0);
  });

  test('resetTracking preserves count for mid-session recovery', () {
    final pipeline = PushupPipeline();
    for (final y in [
      for (var i = 0; i < 20; i++) 100.0,
      for (var i = 0; i < 20; i++) 200.0,
    ]) {
      pipeline.process(_keypoints(y));
    }
    expect(pipeline.count, 1);

    pipeline.resetTracking();
    expect(pipeline.count, 1);

    for (final y in [
      for (var i = 0; i < 20; i++) 100.0,
      for (var i = 0; i < 20; i++) 200.0,
    ]) {
      pipeline.process(_keypoints(y));
    }
    expect(pipeline.count, 2);
  });
}

/// Builds 17 keypoints where the head+shoulders sit at vertical position [y]
/// (driving torsoY) and wrists are well below (so handsSupported is true). When
/// the body is low (y large) the elbows bend sharply; at the top they extend,
/// giving the >25° elbow swing the counter requires.
List<KeyPoint> _keypoints(double y) {
  final low = y > 150;
  // Elbow must have a lateral offset to produce a non-straight angle. At the
  // top (arms extended) it sits nearly on the shoulder-wrist line (~160°); at
  // the bottom it bows out for a sharp bend (~80°), giving the >25° swing.
  final lElbowX = low ? 250.0 : 295.0;
  final rElbowX = low ? 470.0 : 425.0;
  final pts = List<KeyPoint>.generate(
    17,
    (i) => KeyPoint(index: i, x: 0, y: 0, confidence: 0.05),
  );
  pts[0] = KeyPoint(index: 0, x: 360, y: y, confidence: 0.9); // nose
  pts[5] = KeyPoint(index: 5, x: 300, y: y + 40, confidence: 0.9); // L shoulder
  pts[6] = KeyPoint(index: 6, x: 420, y: y + 40, confidence: 0.9); // R shoulder
  pts[7] = KeyPoint(
    index: 7,
    x: lElbowX,
    y: y + 160,
    confidence: 0.9,
  ); // L elbow
  pts[8] = KeyPoint(
    index: 8,
    x: rElbowX,
    y: y + 160,
    confidence: 0.9,
  ); // R elbow
  pts[9] = KeyPoint(index: 9, x: 300, y: y + 280, confidence: 0.9); // L wrist
  pts[10] = KeyPoint(index: 10, x: 420, y: y + 280, confidence: 0.9); // R wrist
  return pts;
}
