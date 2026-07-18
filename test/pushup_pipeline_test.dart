import 'package:test/test.dart';
import 'package:ugk_exercise/product/pushup_pipeline.dart';
import 'package:ugk_exercise/pushup_domain.dart';

/// Verifies the pipeline assembly (extractor → counter-owned smoothing)
/// including close-range arm dropout and diagnostic wrist drift that must not
/// block torso motion.
void main() {
  test('counts synthetic reps through the assembled pipeline', () {
    final pipeline = PushupPipeline();
    CounterState state = const CounterState.initial();

    // A rep is up -> down -> up; build 3 complete reps.
    final ys = <double>[
      for (var r = 0; r < 3; r++) ...[
        for (var i = 0; i < 10; i++) 100,
        for (var i = 0; i < 10; i++) 200,
        for (var i = 0; i < 10; i++) 100,
      ],
    ];
    for (final y in ys) {
      state = pipeline.process(_keypoints(y));
    }

    expect(state.count, 3);
  });

  test('reset clears the count for a fresh session', () {
    final pipeline = PushupPipeline();
    // One complete rep: up -> down -> up.
    for (final y in [
      for (var i = 0; i < 20; i++) 100.0,
      for (var i = 0; i < 20; i++) 200.0,
      for (var i = 0; i < 20; i++) 100.0,
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
      for (var i = 0; i < 20; i++) 100.0,
    ]) {
      pipeline.process(_keypoints(y));
    }
    expect(pipeline.count, 1);

    pipeline.resetTracking();
    expect(pipeline.count, 1);

    for (final y in [
      for (var i = 0; i < 20; i++) 100.0,
      for (var i = 0; i < 20; i++) 200.0,
      for (var i = 0; i < 20; i++) 100.0,
    ]) {
      pipeline.process(_keypoints(y));
    }
    expect(pipeline.count, 2);
  });

  test('counts a torso rep after arms leave the frame', () {
    final pipeline = PushupPipeline();

    for (var i = 0; i < 20; i++) {
      pipeline.process(_keypoints(100));
    }
    for (final y in [
      for (var i = 0; i < 20; i++) 200.0,
      for (var i = 0; i < 20; i++) 100.0,
    ]) {
      pipeline.process(_keypoints(y, armsVisible: false));
    }

    expect(pipeline.count, 1);
  });

  test('counts a fast torso rep within three return frames', () {
    final pipeline = PushupPipeline();

    for (var i = 0; i < 20; i++) {
      pipeline.process(_keypoints(100));
    }
    for (var i = 0; i < 3; i++) {
      pipeline.process(_keypoints(200, armsVisible: false));
    }
    for (var i = 0; i < 2; i++) {
      pipeline.process(_keypoints(100, armsVisible: false));
    }
    expect(pipeline.count, 0);

    pipeline.process(_keypoints(100, armsVisible: false));

    expect(pipeline.count, 1);
  });

  test('counts a fast narrow-eligible rep within three return frames', () {
    final pipeline = PushupPipeline();

    for (var i = 0; i < 20; i++) {
      pipeline.process(
        _keypoints(100),
        repCompletionDecision: RepCompletionDecision.allow,
      );
    }
    for (var i = 0; i < 3; i++) {
      pipeline.process(
        _keypoints(200, armsVisible: false),
        repCompletionDecision: RepCompletionDecision.wait,
      );
    }
    for (var i = 0; i < 3; i++) {
      pipeline.process(
        _keypoints(100),
        repCompletionDecision: RepCompletionDecision.allow,
      );
    }

    expect(pipeline.count, 1);
  });

  test('bottom arm occlusion does not discard a gated rep', () {
    final pipeline = PushupPipeline();

    for (var i = 0; i < 20; i++) {
      pipeline.process(_keypoints(100));
    }
    for (var i = 0; i < 20; i++) {
      pipeline.process(
        _keypoints(200, armsVisible: false),
        repCompletionDecision: RepCompletionDecision.wait,
      );
    }
    for (var i = 0; i < 20; i++) {
      pipeline.process(
        _keypoints(100, armsVisible: false),
        repCompletionDecision: RepCompletionDecision.wait,
      );
    }
    expect(pipeline.count, 0);

    pipeline.process(
      _keypoints(100),
      repCompletionDecision: RepCompletionDecision.allow,
    );
    expect(pipeline.count, 1);
  });

  test('explicitly rejected top form resolves without counting', () {
    final pipeline = PushupPipeline();

    for (final y in [
      for (var i = 0; i < 20; i++) 100.0,
      for (var i = 0; i < 20; i++) 200.0,
      for (var i = 0; i < 20; i++) 100.0,
    ]) {
      pipeline.process(
        _keypoints(y),
        repCompletionDecision: y == 100
            ? RepCompletionDecision.reject
            : RepCompletionDecision.wait,
      );
    }

    expect(pipeline.count, 0);
  });

  test('ready-relative depth rejects 45% adjustment and counts 50% rep', () {
    final pipeline = PushupPipeline();
    final readyPose = _keypoints(100, wristY: 600);

    expect(pipeline.calibrateReadyDepth(readyPose), isTrue);
    for (final y in [
      for (var i = 0; i < 20; i++) 100.0,
      for (var i = 0; i < 20; i++) 310.0,
      for (var i = 0; i < 20; i++) 100.0,
    ]) {
      pipeline.process(_keypoints(y, armsVisible: false));
    }
    expect(pipeline.count, 0);

    for (final y in [
      for (var i = 0; i < 20; i++) 337.0,
      for (var i = 0; i < 20; i++) 100.0,
    ]) {
      pipeline.process(_keypoints(y, armsVisible: false));
    }
    expect(pipeline.count, 1);
  });

  test('equal relative depth counts at near and far image scales', () {
    final near = PushupPipeline();
    final far = PushupPipeline();

    expect(near.calibrateReadyDepth(_keypoints(100, wristY: 600)), isTrue);
    expect(far.calibrateReadyDepth(_keypoints(100, wristY: 350)), isTrue);

    for (var i = 0; i < 20; i++) {
      near.process(_keypoints(100));
      far.process(_keypoints(100));
    }
    for (var i = 0; i < 20; i++) {
      near.process(_keypoints(337, armsVisible: false));
      far.process(_keypoints(212, armsVisible: false));
    }
    for (var i = 0; i < 20; i++) {
      near.process(_keypoints(100, armsVisible: false));
      far.process(_keypoints(100, armsVisible: false));
    }

    expect(near.count, 1);
    expect(far.count, near.count);
  });

  test('counts a 60% relative rep when the subject scale is small', () {
    final pipeline = PushupPipeline();

    expect(pipeline.calibrateReadyDepth(_keypoints(100, wristY: 247)), isTrue);
    expect(pipeline.readyGroundSpan, lessThan(160));

    for (final y in [
      for (var i = 0; i < 20; i++) 100.0,
      for (var i = 0; i < 20; i++) 172.0,
      for (var i = 0; i < 20; i++) 100.0,
    ]) {
      pipeline.process(_keypoints(y, armsVisible: false));
    }

    expect(pipeline.count, 1);
  });

  test('rejects a 45% adjustment when the subject scale is small', () {
    final pipeline = PushupPipeline();

    expect(pipeline.calibrateReadyDepth(_keypoints(100, wristY: 247)), isTrue);
    final adjustmentY = 100 + pipeline.readyGroundSpan! * 0.45;
    for (final y in [
      for (var i = 0; i < 20; i++) 100.0,
      for (var i = 0; i < 20; i++) adjustmentY,
      for (var i = 0; i < 20; i++) 100.0,
    ]) {
      pipeline.process(_keypoints(y, armsVisible: false));
    }

    expect(pipeline.count, 0);
  });

  test('rejects 25px tracking jitter at an extreme small scale', () {
    final pipeline = PushupPipeline();

    expect(pipeline.calibrateReadyDepth(_keypoints(100, wristY: 175)), isTrue);
    expect(pipeline.readyGroundSpan, lessThan(50));
    for (final y in [
      for (var i = 0; i < 20; i++) 100.0,
      for (var i = 0; i < 20; i++) 125.0,
      for (var i = 0; i < 20; i++) 100.0,
    ]) {
      pipeline.process(_keypoints(y, armsVisible: false));
    }

    expect(pipeline.count, 0);
  });

  test('wrist drift verdict does not freeze torso motion after ready', () {
    final pipeline = PushupPipeline();

    for (var i = 0; i < 20; i++) {
      pipeline.process(_keypoints(100));
    }
    for (final y in [
      for (var i = 0; i < 20; i++) 200.0,
      for (var i = 0; i < 20; i++) 100.0,
    ]) {
      pipeline.process(_keypoints(y), handsStable: false);
    }

    expect(pipeline.count, 1);
  });

  test('counts the same motion at 1280p and 720p source heights', () {
    final fullHeight = PushupPipeline();
    final mediumHeight = PushupPipeline();
    final ys = [
      for (var i = 0; i < 20; i++) 100.0,
      for (var i = 0; i < 20; i++) 200.0,
      for (var i = 0; i < 20; i++) 100.0,
    ];

    for (final y in ys) {
      final keypoints = _keypoints(y);
      fullHeight.process(keypoints, sourceHeight: 1280);
      mediumHeight.process(
        _scaleKeypoints(keypoints, 720 / 1280),
        sourceHeight: 720,
      );
    }

    expect(fullHeight.count, 1);
    expect(mediumHeight.count, fullHeight.count);
  });
}

List<KeyPoint> _scaleKeypoints(List<KeyPoint> keypoints, double scale) {
  return [
    for (final point in keypoints)
      KeyPoint(
        index: point.index,
        x: point.x * scale,
        y: point.y * scale,
        confidence: point.confidence,
      ),
  ];
}

/// Builds 17 keypoints where the head+shoulders sit at vertical position [y]
/// (driving torsoY) and wrists are well below (so handsSupported is true). When
/// the body is low (y large) the elbows bend sharply; at the top they extend,
/// giving the >25° elbow swing that visible elbow evidence should confirm.
List<KeyPoint> _keypoints(double y, {bool armsVisible = true, double? wristY}) {
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
    confidence: armsVisible ? 0.9 : 0.05,
  ); // L elbow
  pts[8] = KeyPoint(
    index: 8,
    x: rElbowX,
    y: y + 160,
    confidence: armsVisible ? 0.9 : 0.05,
  ); // R elbow
  pts[9] = KeyPoint(
    index: 9,
    x: 300,
    y: wristY ?? y + 280,
    confidence: armsVisible ? 0.9 : 0.05,
  ); // L wrist
  pts[10] = KeyPoint(
    index: 10,
    x: 420,
    y: wristY ?? y + 280,
    confidence: armsVisible ? 0.9 : 0.05,
  ); // R wrist
  return pts;
}
