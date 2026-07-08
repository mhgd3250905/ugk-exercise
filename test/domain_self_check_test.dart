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

  test('SignalFilter smooths jitter and holds through NaN', () {
    final filter = SignalFilter(window: 3);

    _close(filter.smooth(_signals(10)).shoulderY, 10);
    _close(filter.smooth(_signals(20)).shoulderY, 15);
    _close(filter.smooth(_signals(double.nan, conf: 0)).shoulderY, 15);
  });

  test('PushupCounter replays Step0 CSV as 5 reps', () {
    final filter = SignalFilter(window: 5);
    final counter = PushupCounter(
      config: const CounterConfig(frameHeight: 1280, fps: 30),
    );

    CounterState state = counter.state;
    for (final row in _readStep0Rows('step0/out_signals.csv')) {
      state = counter.update(
        filter.smooth(
          _signals(
            row.shoulderY,
            conf: row.shoulderConf,
            frame: row.frame,
            timeS: row.timeS,
          ),
        ),
      );
    }

    _expect(state.count == 5, 'expected 5 reps, got ${state.count}');
  });

  test('PushupCounter replays video3 (50fps resampled to 30fps) as 5 reps', () {
    final counter = PushupCounter(
      config: const CounterConfig(frameHeight: 720, fps: 30),
    );

    CounterState state = counter.state;
    for (final row in _readStep0Rows('step0/v3/out_signals.csv')) {
      // Original video is 50fps: resample to 30fps before counting.
      if (!_keepAt30fps(row.frame, fromFps: 50)) continue;
      state = counter.update(
        _signals(
          row.shoulderY,
          conf: row.shoulderConf,
          frame: row.frame,
          timeS: row.timeS,
        ),
      );
    }

    _expect(state.count == 5, 'expected 5 reps, got ${state.count}');
  });

  test('PushupCounter replays video4 (72 frames @30fps) as 3 reps', () {
    final counter = PushupCounter(
      config: const CounterConfig(frameHeight: 720, fps: 30),
    );

    CounterState state = counter.state;
    for (final row in _readStep0Rows('step0/v4/out_signals.csv')) {
      state = counter.update(
        _signals(
          row.shoulderY,
          conf: row.shoulderConf,
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

  test('PushupCounter counts fast synthetic reps up to 3/s @30fps', () {
    // 1 rep/s for 3 s: 10 frames down + 10 frames up, repeated 3 times.
    final slow = <double>[
      for (var r = 0; r < 3; r++) ...[
        for (var i = 0; i < 10; i++) 100,
        for (var i = 0; i < 10; i++) 200,
      ],
    ];
    _expect(
      _runCounter(slow).count == 3,
      '1/s x3 should count 3',
    );

    // 2/s for 2 s: 15-frame cycle, repeated 4 times.
    final med = <double>[
      for (var r = 0; r < 4; r++) ...[
        for (var i = 0; i < 7; i++) 100,
        for (var i = 0; i < 8; i++) 200,
      ],
    ];
    _expect(
      _runCounter(med).count == 4,
      '2/s x4 should count 4',
    );

    // 3/s for 1 s: 10-frame cycle, repeated 3 times.
    final fast = <double>[
      for (var r = 0; r < 3; r++) ...[
        for (var i = 0; i < 5; i++) 100,
        for (var i = 0; i < 5; i++) 200,
      ],
    ];
    _expect(
      _runCounter(fast).count == 3,
      '3/s x3 should count 3',
    );
  });

  test('PushupCounter ignores low-amplitude and low-confidence frames', () {
    // A real-looking shape but only 5px tall: below the absolute floor.
    final lowAmp = <double>[
      for (var r = 0; r < 3; r++) ...[
        for (var i = 0; i < 10; i++) 100,
        for (var i = 0; i < 10; i++) 105,
      ],
    ];
    _expect(
      _runCounter(lowAmp).count == 0,
      'low amplitude must not count',
    );

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
  int? frame,
  double? timeS,
}) {
  return FrameSignals(
    frame: frame,
    timeS: timeS,
    shoulderY: shoulderY,
    shoulderConf: conf,
    elbowConf: conf,
    noseConf: conf,
    raw: const [],
  );
}

/// Feeds a shoulder_y sequence to a fresh counter and returns the final state.
CounterState _runCounter(List<double> ys) {
  final counter = PushupCounter();
  CounterState state = counter.state;
  for (final y in ys) {
    state = counter.update(_signals(y));
  }
  return state;
}

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
      shoulderY: double.parse(row['shoulder_y']!),
      shoulderConf: double.parse(row['shoulder_conf']!),
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
    required this.shoulderY,
    required this.shoulderConf,
  });

  final int frame;
  final double timeS;
  final double shoulderY;
  final double shoulderConf;
}
