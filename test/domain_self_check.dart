import 'dart:convert';
import 'dart:io';

// ignore_for_file: avoid_relative_lib_imports
import '../lib/pushup_domain.dart';

void main() {
  final failures = <String>[];

  void check(String name, void Function() body) {
    try {
      body();
      stdout.writeln('PASS $name');
    } catch (error, stack) {
      failures.add('$name\n$error\n$stack');
      stderr.writeln('FAIL $name: $error');
    }
  }

  check('SignalExtractor weights shoulders and ignores low confidence', () {
    final keypoints = _blankKeypoints();
    keypoints[5] = const KeyPoint(index: 5, x: 10, y: 100, confidence: 0.05);
    keypoints[6] = const KeyPoint(index: 6, x: 20, y: 300, confidence: 0.95);
    keypoints[7] = const KeyPoint(index: 7, x: 500, y: 0, confidence: 0.7);
    keypoints[8] = const KeyPoint(index: 8, x: 200, y: 0, confidence: 0.8);

    final signals = const SignalExtractor().toSignals(keypoints);

    _close(signals.shoulderY, 300);
    _close(signals.elbowLateral!, 300);
  });

  check('SignalExtractor returns NaN when both shoulders are unusable', () {
    final keypoints = _blankKeypoints();
    keypoints[5] = const KeyPoint(index: 5, x: 0, y: 100, confidence: 0.05);
    keypoints[6] = const KeyPoint(index: 6, x: 0, y: 200, confidence: 0.09);

    final signals = const SignalExtractor().toSignals(keypoints);

    _expect(signals.shoulderY.isNaN, 'shoulderY should be NaN');
  });

  check('SignalFilter smooths jitter and holds through NaN', () {
    final filter = SignalFilter(window: 3);

    _close(filter.smooth(_signals(10)).shoulderY, 10);
    _close(filter.smooth(_signals(20)).shoulderY, 15);
    _close(filter.smooth(_signals(double.nan, conf: 0)).shoulderY, 15);
  });

  check('PushupCounter replays Step0 CSV as 5 reps', () {
    final filter = SignalFilter(window: 5);
    final counter = PushupCounter(
      config: const CounterConfig(frameHeight: 1280, fps: 30),
    );

    CounterState state = counter.state;
    for (final row in _readStep0Rows()) {
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

  check('PushupCounter counts synthetic slow and fast cycles', () {
    _expect(
      _runSynthetic([200, 200, 100, 100, 200, 200, 100, 100]) == 2,
      'slow cycles should count 2',
    );
    _expect(
      _runSynthetic([200, 100, 200, 100, 200, 100]) == 3,
      'fast cycles should count 3',
    );
  });

  check('PushupCounter ignores low amplitude and low confidence', () {
    _expect(
      _runSynthetic([105, 100, 105, 100], high: 105, low: 100) == 0,
      'low amplitude should not count',
    );
    _expect(
      _runSynthetic([200, 100, 200, 100], activeConf: 0.1) == 0,
      'low confidence should not count',
    );
  });

  check('PushupCounter drops a timed-out half cycle', () {
    final counter = _seededCounter(
      const CounterConfig(
        windowN: 10,
        minCalibrationFrames: 10,
        minGapFrames: 1,
        mDown: 1,
        mUp: 1,
        frameHeight: 1000,
        ampMinRatio: 0.01,
        fps: 10,
        cycleTimeoutMs: 300,
      ),
    );

    CounterState state = counter.state;
    for (final y in [200, 200, 200, 200, 200, 100, 100]) {
      state = counter.update(_signals(y.toDouble()));
    }

    _expect(state.count == 0, 'timed-out half cycle should be dropped');
  });

  if (failures.isNotEmpty) {
    stderr.writeln('\n${failures.join('\n')}');
    exitCode = 1;
  }
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

int _runSynthetic(
  List<num> active, {
  double high = 200,
  double low = 100,
  double activeConf = 0.9,
}) {
  final counter = _seededCounter(
    const CounterConfig(
      windowN: 10,
      minCalibrationFrames: 10,
      minGapFrames: 1,
      mDown: 1,
      mUp: 1,
      frameHeight: 1000,
      ampMinRatio: 0.01,
    ),
    high: high,
    low: low,
  );

  CounterState state = counter.state;
  for (final y in active) {
    state = counter.update(_signals(y.toDouble(), conf: activeConf));
  }
  return state.count;
}

PushupCounter _seededCounter(
  CounterConfig config, {
  double high = 200,
  double low = 100,
}) {
  final counter = PushupCounter(config: config);
  for (final y in [low, high, low, high, low, high, low, high, low, low]) {
    counter.update(_signals(y.toDouble()));
  }
  return counter;
}

Iterable<_CsvRow> _readStep0Rows() sync* {
  final file = File('step0/out_signals.csv');
  final lines = file.readAsLinesSync();
  final headers = const LineSplitter().convert(lines.first).first.split(',');
  for (final line in lines.skip(1)) {
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
