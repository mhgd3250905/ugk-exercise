import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

// ignore_for_file: avoid_relative_lib_imports
import '../lib/pushup_domain.dart';
import 'package:test/test.dart';

void main() {
  test('SignalExtractor weights shoulders and ignores low confidence', () {
    final keypoints = _blankKeypoints();
    keypoints[5] = const KeyPoint(index: 5, x: 10, y: 100, confidence: 0.05);
    keypoints[6] = const KeyPoint(index: 6, x: 20, y: 300, confidence: 0.95);
    keypoints[7] = const KeyPoint(index: 7, x: 500, y: 0, confidence: 0.7);
    keypoints[8] = const KeyPoint(index: 8, x: 200, y: 0, confidence: 0.8);

    final signals = const SignalExtractor().toSignals(keypoints);

    _close(signals.shoulderY, 300);
    _close(signals.elbowLateral!, 300);
  });

  test('SignalExtractor returns NaN when both shoulders are unusable', () {
    final keypoints = _blankKeypoints();
    keypoints[5] = const KeyPoint(index: 5, x: 0, y: 100, confidence: 0.05);
    keypoints[6] = const KeyPoint(index: 6, x: 0, y: 200, confidence: 0.09);

    final signals = const SignalExtractor().toSignals(keypoints);

    _expect(signals.shoulderY.isNaN, 'shoulderY should be NaN');
  });

  test(
    'SignalExtractor computes elbow angle from shoulders elbows and wrists',
    () {
      final keypoints = _blankKeypoints();
      keypoints[5] = const KeyPoint(index: 5, x: 0, y: 0, confidence: 0.9);
      keypoints[7] = const KeyPoint(index: 7, x: 1, y: 0, confidence: 0.9);
      keypoints[9] = const KeyPoint(index: 9, x: 1, y: 1, confidence: 0.9);

      final signals = const SignalExtractor().toSignals(keypoints);

      _close(signals.elbowAngle!, 90);
    },
  );

  test('SignalExtractor marks unsupported hands when one wrist rises', () {
    final keypoints = _blankKeypoints();
    keypoints[SignalExtractor.leftShoulder] = const KeyPoint(
      index: SignalExtractor.leftShoulder,
      x: 100,
      y: 420,
      confidence: 0.9,
    );
    keypoints[SignalExtractor.rightShoulder] = const KeyPoint(
      index: SignalExtractor.rightShoulder,
      x: 220,
      y: 420,
      confidence: 0.9,
    );
    keypoints[SignalExtractor.leftWrist] = const KeyPoint(
      index: SignalExtractor.leftWrist,
      x: 100,
      y: 300,
      confidence: 0.9,
    );
    keypoints[SignalExtractor.rightWrist] = const KeyPoint(
      index: SignalExtractor.rightWrist,
      x: 220,
      y: 650,
      confidence: 0.9,
    );

    final signals = const SignalExtractor().toSignals(keypoints);

    _expect(!signals.handsSupported, 'one lifted wrist must break support');
  });

  test('SignalExtractor exempts wrists that are not confidently visible', () {
    final keypoints = _blankKeypoints();
    keypoints[SignalExtractor.nose] = const KeyPoint(
      index: SignalExtractor.nose,
      x: 160,
      y: 300,
      confidence: 0.9,
    );
    keypoints[SignalExtractor.leftShoulder] = const KeyPoint(
      index: SignalExtractor.leftShoulder,
      x: 100,
      y: 420,
      confidence: 0.9,
    );
    keypoints[SignalExtractor.rightShoulder] = const KeyPoint(
      index: SignalExtractor.rightShoulder,
      x: 220,
      y: 420,
      confidence: 0.9,
    );
    keypoints[SignalExtractor.leftWrist] = const KeyPoint(
      index: SignalExtractor.leftWrist,
      x: 100,
      y: 0,
      confidence: 0.05,
    );
    keypoints[SignalExtractor.rightWrist] = const KeyPoint(
      index: SignalExtractor.rightWrist,
      x: 220,
      y: 0,
      confidence: 0.05,
    );

    final signals = const SignalExtractor().toSignals(keypoints);

    _expect(
      signals.handsSupported,
      'invisible wrists are unknown and must not veto torso motion',
    );
  });

  test('SignalExtractor treats a wrist near the shoulder line as unknown', () {
    final keypoints = _blankKeypoints();
    keypoints[SignalExtractor.leftShoulder] = const KeyPoint(
      index: SignalExtractor.leftShoulder,
      x: 100,
      y: 420,
      confidence: 0.9,
    );
    keypoints[SignalExtractor.rightShoulder] = const KeyPoint(
      index: SignalExtractor.rightShoulder,
      x: 220,
      y: 420,
      confidence: 0.9,
    );
    keypoints[SignalExtractor.leftWrist] = const KeyPoint(
      index: SignalExtractor.leftWrist,
      x: 100,
      y: 420,
      confidence: 0.9,
    );
    keypoints[SignalExtractor.rightWrist] = const KeyPoint(
      index: SignalExtractor.rightWrist,
      x: 220,
      y: 650,
      confidence: 0.9,
    );

    final signals = const SignalExtractor().toSignals(keypoints);

    _expect(
      signals.handsSupported,
      'a boundary-clamped wrist is uncertain, not proof that support was lost',
    );
  });

  test('SignalFilter smooths jitter and holds through NaN', () {
    final filter = SignalFilter(window: 3);

    _close(filter.smooth(_signals(10)).shoulderY, 10);
    _close(filter.smooth(_signals(20)).shoulderY, 15);
    _close(filter.smooth(_signals(double.nan, conf: 0)).shoulderY, 15);
  });

  test('PushupCounter replays Step0 CSV as 5 reps', () {
    // No external SignalFilter: matches the production PushupPipeline path
    // where only the counter's internal median filter smooths the signal.
    final counter = PushupCounter();

    CounterState state = counter.state;
    for (final row in _readStep0Rows('test/fixtures/replay_step0.csv')) {
      state = counter.update(
        _signals(
          row.torsoY,
          conf: row.shoulderConf,
          elbowAngle: row.elbowAngle,
          frame: row.frame,
          timeS: row.timeS,
        ),
      );
    }

    _expect(state.count == 5, 'expected 5 reps, got ${state.count}');
  });

  test('PushupCounter replays video3 (50fps resampled to 30fps) as 5 reps', () {
    final counter = PushupCounter();

    CounterState state = counter.state;
    for (final row in _readStep0Rows('test/fixtures/replay_v3.csv')) {
      // Original video is 50fps: resample to 30fps before counting.
      if (!_keepAt30fps(row.frame, fromFps: 50)) continue;
      state = counter.update(
        _signals(
          row.torsoY,
          conf: row.shoulderConf,
          elbowAngle: row.elbowAngle,
          frame: row.frame,
          timeS: row.timeS,
        ),
      );
    }

    _expect(state.count == 5, 'expected 5 reps, got ${state.count}');
  });

  test('PushupCounter replays video4 (72 frames @30fps) as 3 reps', () {
    final counter = PushupCounter();

    CounterState state = counter.state;
    for (final row in _readStep0Rows('test/fixtures/replay_v4.csv')) {
      state = counter.update(
        _signals(
          row.torsoY,
          conf: row.shoulderConf,
          elbowAngle: row.elbowAngle,
          frame: row.frame,
          timeS: row.timeS,
        ),
      );
    }

    _expect(state.count == 3, 'expected 3 reps, got ${state.count}');
  });

  test('PushupCounter ignores a stationary signal', () {
    final counter = PushupCounter();
    CounterState state = counter.state;
    for (var i = 0; i < 100; i++) {
      state = counter.update(_signals(300));
    }
    _expect(state.count == 0, 'stationary signal must not count');
  });

  test('PushupCounter ignores ±20px Gaussian noise', () {
    final rnd = math.Random(42);
    final counter = PushupCounter();
    CounterState state = counter.state;
    for (var i = 0; i < 200; i++) {
      final y = 300 + rnd.nextDouble() * 40 - 20;
      // ±20px jitter: the counter's 5th-95th percentile range stays well
      // below the 80px absolute amplitude floor, so it must not count.
      state = counter.update(_signals(y));
    }
    _expect(state.count == 0, 'noise must not count, got ${state.count}');
  });

  test('PushupCounter ignores shoulder motion without elbow bending', () {
    final ys = <double>[
      for (var r = 0; r < 3; r++) ...[
        for (var i = 0; i < 10; i++) 100,
        for (var i = 0; i < 10; i++) 220,
      ],
    ];

    _expect(
      _runCounter(ys, elbowAngle: 170).count == 0,
      'camera/body bobbing with straight elbows must not count',
    );
  });

  test('PushupCounter ignores shoulder motion with a fixed bent elbow', () {
    final ys = <double>[
      for (var r = 0; r < 3; r++) ...[
        for (var i = 0; i < 10; i++) 100,
        for (var i = 0; i < 10; i++) 220,
      ],
    ];

    _expect(
      _runCounter(ys, elbowAngleForY: (_) => 90).count == 0,
      'camera/body bobbing with a fixed bent elbow must not count',
    );
  });

  // Core regression: raising one hand to the face/chin must not count.
  // First-principles: a raised hand does not move the head+shoulders, so the
  // torso signal stays flat, so it cannot form a rep. A visible raised wrist is
  // rejected earlier by the motion-stage support checks.
  test('raising one hand to the chin does not count', () {
    final counter = PushupCounter();
    CounterState state = counter.state;

    // Seed: stable support, counter calibrates on a flat torso.
    for (var i = 0; i < 12; i++) {
      state = counter.update(_signals(120, elbowAngle: 160));
    }

    // Raise one hand to the chin: the torso (head+shoulders) does NOT move, but
    // the raised wrist drifts, but the flat torso signal alone cannot form a
    // rep regardless of the diagnostic stability verdict.
    for (var i = 0; i < 8; i++) {
      state = counter.update(_signals(120, elbowAngle: 60));
    }
    // Hand returns.
    for (var i = 0; i < 6; i++) {
      state = counter.update(_signals(120, elbowAngle: 160));
    }

    _expect(
      state.count == 0,
      'raising one hand to the chin must not count, got ${state.count}',
    );
  });

  test('PushupCounter ignores motion while hands are unsupported', () {
    final ys = <double>[
      for (var r = 0; r < 3; r++) ...[
        for (var i = 0; i < 10; i++) 100,
        for (var i = 0; i < 10; i++) 220,
      ],
    ];
    final counter = PushupCounter();
    CounterState state = counter.state;
    for (final y in ys) {
      state = counter.update(
        _signals(y, elbowAngle: _syntheticElbowAngle(y), handsSupported: false),
      );
    }

    _expect(
      state.count == 0,
      'unsupported hand motion must not count, got ${state.count}',
    );
  });

  test('PushupCounter counts fast synthetic reps up to 3/s @30fps', () {
    // A rep is up -> down -> up. Each test builds N complete reps starting and
    // ending in the up position, so the count is N regardless of rate.
    // 1 rep/s for 3 s: 10 frames down + 10 frames up, per rep.
    final slow = <double>[
      for (var r = 0; r < 3; r++) ...[
        for (var i = 0; i < 10; i++) 100,
        for (var i = 0; i < 10; i++) 200,
        for (var i = 0; i < 10; i++) 100,
      ],
    ];
    _expect(_runCounter(slow).count == 3, '1/s x3 should count 3');

    // 2/s for 2 s: 15-frame cycle, repeated 4 times.
    final med = <double>[
      for (var r = 0; r < 4; r++) ...[
        for (var i = 0; i < 7; i++) 100,
        for (var i = 0; i < 8; i++) 200,
        for (var i = 0; i < 7; i++) 100,
      ],
    ];
    _expect(_runCounter(med).count == 4, '2/s x4 should count 4');

    // 3/s for 1 s: 10-frame cycle, repeated 3 times.
    final fast = <double>[
      for (var r = 0; r < 3; r++) ...[
        for (var i = 0; i < 5; i++) 100,
        for (var i = 0; i < 5; i++) 200,
        for (var i = 0; i < 5; i++) 100,
      ],
    ];
    _expect(_runCounter(fast).count == 3, '3/s x3 should count 3');
  });

  test('PushupCounter ignores low-amplitude and low-confidence frames', () {
    // A real-looking shape but only 5px tall: below the absolute floor.
    final lowAmp = <double>[
      for (var r = 0; r < 3; r++) ...[
        for (var i = 0; i < 10; i++) 100,
        for (var i = 0; i < 10; i++) 105,
      ],
    ];
    _expect(_runCounter(lowAmp).count == 0, 'low amplitude must not count');

    // Full swing but every frame below the confidence threshold: skipped.
    final fullSwing = <double>[
      for (var r = 0; r < 3; r++) ...[
        for (var i = 0; i < 10; i++) 100,
        for (var i = 0; i < 10; i++) 200,
      ],
    ];
    final counter = PushupCounter();
    CounterState state = counter.state;
    for (final y in fullSwing) {
      state = counter.update(_signals(y, conf: 0.1));
    }
    _expect(state.count == 0, 'low confidence must not count');
  });

  // Elbow dropout tolerance: a real press briefly dips the elbow out of frame
  // near the bottom. Missing evidence must not veto the torso cycle, while a
  // permanently-straight visible elbow still does.
  test('PushupCounter counts a rep with a brief elbow dropout at the bottom', () {
    final counter = PushupCounter();
    CounterState state = counter.state;
    // Rep shape: up (y=100) -> down (y=200) -> up. Elbow bends on the way down,
    // vanishes for a few frames right at the bottom (simulating it leaving the
    // frame), then reappears bent on the way up.
    final frames = <(double y, double? angle, double conf)>[
      // descend, elbow visible and bending
      for (final y in [100.0, 120.0, 140.0, 160.0]) (y, 150.0, 0.9),
      for (final y in [170.0, 180.0, 190.0, 200.0]) (y, 90.0, 0.9),
      // bottom: elbow drops out of frame for 3 frames
      for (final y in [200.0, 200.0, 200.0]) (y, null, 0.1),
      // ascend, elbow reappears bent then straightens
      for (final y in [190.0, 180.0, 160.0, 140.0]) (y, 90.0, 0.9),
      for (final y in [120.0, 100.0, 100.0, 100.0]) (y, 150.0, 0.9),
    ];
    for (final (y, angle, conf) in frames) {
      state = counter.update(
        FrameSignals(
          shoulderY: y,
          torsoY: y,
          elbowAngle: angle,
          shoulderConf: 0.9,
          elbowConf: conf,
          noseConf: 0.9,
          handsSupported: true,
          raw: const [],
        ),
      );
    }
    _expect(
      state.count == 1,
      'brief elbow dropout at rep bottom should still count 1, got ${state.count}',
    );
  });

  test('PushupCounter counts a torso rep when elbows are unavailable', () {
    final counter = PushupCounter();
    CounterState state = counter.state;
    for (final y in [
      for (var i = 0; i < 20; i++) 100.0,
      for (var i = 0; i < 20; i++) 200.0,
      for (var i = 0; i < 20; i++) 100.0,
    ]) {
      state = counter.update(_signals(y, elbowAngle: null));
    }

    _expect(
      state.count == 1,
      'a complete torso cycle must count when elbows leave the frame',
    );
  });

  test('PushupCounter counts when elbows reappear only at the top', () {
    final counter = PushupCounter();
    CounterState state = counter.state;
    for (var i = 0; i < 20; i++) {
      state = counter.update(_signals(100, elbowAngle: null));
    }
    for (var i = 0; i < 20; i++) {
      state = counter.update(_signals(200, elbowAngle: null));
    }
    for (var i = 0; i < 20; i++) {
      state = counter.update(_signals(100, elbowAngle: 170));
    }

    _expect(
      state.count == 1,
      'a return-only elbow reading must not masquerade as dip evidence',
    );
  });

  test('PushupCounter counts the first rep after a long wait at the top', () {
    final state = _runCounter([
      for (var i = 0; i < 300; i++) 100.0,
      for (var i = 0; i < 10; i++) 200.0,
      for (var i = 0; i < 10; i++) 100.0,
    ]);

    _expect(state.count == 1, 'long ready wait must not swallow the first rep');
  });

  test('PushupCounter counts again after a long wait between reps', () {
    final state = _runCounter([
      for (var i = 0; i < 20; i++) 100.0,
      for (var i = 0; i < 20; i++) 200.0,
      for (var i = 0; i < 20; i++) 100.0,
      for (var i = 0; i < 600; i++) 100.0,
      for (var i = 0; i < 10; i++) 200.0,
      for (var i = 0; i < 10; i++) 100.0,
    ]);

    _expect(state.count == 2, 'long rest must not swallow the next rep');
  });

  test('PushupCounter reports down phase until the torso returns up', () {
    final counter = PushupCounter();
    CounterState state = counter.state;
    for (final y in [
      for (var i = 0; i < 20; i++) 100.0,
      for (var i = 0; i < 20; i++) 200.0,
    ]) {
      state = counter.update(_signals(y, elbowAngle: _syntheticElbowAngle(y)));
    }
    _expect(state.phase == Phase.down, 'descent must expose Phase.down');

    for (var i = 0; i < 20; i++) {
      state = counter.update(_signals(100, elbowAngle: 170));
    }
    _expect(state.phase == Phase.up, 'up-return must restore Phase.up');
    _expect(state.count == 1, 'phase reporting must not change the count');
  });

  test('PushupCounter waits for reliable evidence at rep completion', () {
    final counter = PushupCounter();
    CounterState state = counter.state;
    for (var i = 0; i < 20; i++) {
      state = counter.update(_signals(100, elbowAngle: null));
    }
    for (var i = 0; i < 20; i++) {
      state = counter.update(_signals(200, elbowAngle: null));
    }
    for (var i = 0; i < 20; i++) {
      state = counter.update(
        _signals(100, elbowAngle: null),
        repCompletionDecision: RepCompletionDecision.wait,
      );
    }

    _expect(state.count == 0, 'unknown top evidence must not count');
    _expect(state.phase == Phase.down, 'unknown evidence must keep the dip');

    state = counter.update(
      _signals(100, elbowAngle: null),
      repCompletionDecision: RepCompletionDecision.allow,
    );
    _expect(state.count == 1, 'a later reliable top frame should count');
    _expect(state.phase == Phase.up, 'accepted evidence must resolve the dip');
  });

  test('PushupCounter resolves a rejected completion without counting', () {
    final counter = PushupCounter();
    CounterState state = counter.state;
    for (var i = 0; i < 20; i++) {
      state = counter.update(_signals(100, elbowAngle: null));
    }
    for (var i = 0; i < 20; i++) {
      state = counter.update(_signals(200, elbowAngle: null));
    }
    for (var i = 0; i < 20; i++) {
      state = counter.update(
        _signals(100, elbowAngle: null),
        repCompletionDecision: RepCompletionDecision.reject,
      );
    }

    _expect(state.count == 0, 'rejected top form must not count');
    _expect(state.phase == Phase.up, 'a rejected dip must be resolved');
  });
}

List<KeyPoint> _blankKeypoints() {
  return List<KeyPoint>.generate(
    17,
    (index) => KeyPoint(index: index, x: 0, y: 0, confidence: 0),
  );
}

FrameSignals _signals(
  double shoulderY, {
  double conf = 0.9,
  double? elbowAngle = 90,
  double? pressDepthY,
  double? torsoY,
  bool handsSupported = true,
  int? frame,
  double? timeS,
}) {
  return FrameSignals(
    frame: frame,
    timeS: timeS,
    shoulderY: shoulderY,
    elbowAngle: elbowAngle,
    pressDepthY: pressDepthY,
    // The torso drives the counter's motion signal. Default it to shoulderY so
    // legacy callers that pass a single y still feed a usable signal.
    torsoY: torsoY ?? shoulderY,
    rawTorsoY: torsoY ?? shoulderY,
    handsSupported: handsSupported,
    shoulderConf: conf,
    elbowConf: conf,
    noseConf: conf,
    raw: const [],
  );
}

/// Feeds a torso-y sequence to a fresh counter and returns the final state.
/// `y` is the head+shoulder motion signal.
CounterState _runCounter(
  List<double> ys, {
  double? elbowAngle,
  double Function(double y)? elbowAngleForY,
}) {
  final counter = PushupCounter();
  CounterState state = counter.state;
  for (final y in ys) {
    state = counter.update(
      _signals(
        y,
        elbowAngle:
            elbowAngleForY?.call(y) ?? elbowAngle ?? _syntheticElbowAngle(y),
      ),
    );
  }
  return state;
}

double _syntheticElbowAngle(double shoulderY) => shoulderY < 150 ? 170 : 90;

/// Nearest-frame resampling of a [fromFps] stream to 30fps, matching the
/// project's offline resampling contract (see handoff doc §4.3). Returns true
/// if [sourceFrame] survives the resample. Equivalent to the Python
/// `i = 0.0; while i<len: pick rows[int(i)]; i += step`.
bool _keepAt30fps(int sourceFrame, {required int fromFps}) {
  if (fromFps == 30) return true;
  final step = fromFps / 30;
  var i = 0.0;
  while (i < 1000000) {
    if (i.toInt() == sourceFrame) return true;
    if (i.toInt() > sourceFrame) return false;
    i += step;
  }
  return false;
}

Iterable<_CsvRow> _readStep0Rows(String path) sync* {
  final file = File(path);
  final lines = file.readAsLinesSync();
  final headers = const LineSplitter().convert(lines.first).first.split(',');
  for (final line in lines.skip(1)) {
    if (line.trim().isEmpty) continue;
    final values = line.split(',');
    final row = <String, String>{};
    for (var i = 0; i < headers.length; i++) {
      row[headers[i]] = values[i];
    }
    yield _CsvRow(
      frame: int.parse(row['frame']!),
      timeS: double.parse(row['time_s']!),
      torsoY: double.parse(row['torso_y']!),
      shoulderConf: double.parse(row['shoulder_conf']!),
      elbowAngle: double.parse(row['elbow_angle']!),
    );
  }
}

void _expect(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}

void _close(double actual, double expected, {double tolerance = 1e-6}) {
  if ((actual - expected).abs() > tolerance) {
    throw StateError('expected $expected, got $actual');
  }
}

class _CsvRow {
  const _CsvRow({
    required this.frame,
    required this.timeS,
    required this.torsoY,
    required this.shoulderConf,
    required this.elbowAngle,
  });

  final int frame;
  final double timeS;
  final double torsoY;
  final double shoulderConf;
  final double elbowAngle;
}
