import 'dart:math' as math;

enum Phase { up, down }

class KeyPoint {
  const KeyPoint({
    required this.index,
    required this.x,
    required this.y,
    required this.confidence,
  });

  final int index;
  final double x;
  final double y;
  final double confidence;
}

class FrameSignals {
  const FrameSignals({
    this.frame,
    this.timeS,
    required this.shoulderY,
    this.headY,
    this.elbowLateral,
    required this.shoulderConf,
    required this.elbowConf,
    required this.noseConf,
    required this.raw,
  });

  final int? frame;
  final double? timeS;
  final double shoulderY;
  final double? headY;
  final double? elbowLateral;
  final double shoulderConf;
  final double elbowConf;
  final double noseConf;
  final List<KeyPoint> raw;

  FrameSignals copyWith({
    double? shoulderY,
    double? headY,
    double? elbowLateral,
    double? shoulderConf,
    double? elbowConf,
    double? noseConf,
  }) {
    return FrameSignals(
      frame: frame,
      timeS: timeS,
      shoulderY: shoulderY ?? this.shoulderY,
      headY: headY ?? this.headY,
      elbowLateral: elbowLateral ?? this.elbowLateral,
      shoulderConf: shoulderConf ?? this.shoulderConf,
      elbowConf: elbowConf ?? this.elbowConf,
      noseConf: noseConf ?? this.noseConf,
      raw: raw,
    );
  }
}

class SignalExtractor {
  const SignalExtractor({this.minConf = 0.1});

  static const int nose = 0;
  static const int leftShoulder = 5;
  static const int rightShoulder = 6;
  static const int leftElbow = 7;
  static const int rightElbow = 8;

  final double minConf;

  FrameSignals toSignals(List<KeyPoint> keypoints) {
    if (keypoints.length < 17) {
      throw ArgumentError.value(
        keypoints.length,
        'keypoints.length',
        'expected 17',
      );
    }

    final leftS = keypoints[leftShoulder];
    final rightS = keypoints[rightShoulder];
    final leftE = keypoints[leftElbow];
    final rightE = keypoints[rightElbow];
    final nosePoint = keypoints[nose];

    final shoulderY = weightedMean(
      [leftS.y, rightS.y],
      [leftS.confidence, rightS.confidence],
      minConf: minConf,
    );
    final elbowUsable =
        leftE.confidence >= minConf && rightE.confidence >= minConf;

    return FrameSignals(
      shoulderY: shoulderY,
      headY: nosePoint.confidence >= minConf ? nosePoint.y : null,
      elbowLateral: elbowUsable ? (leftE.x - rightE.x).abs() : null,
      shoulderConf: (leftS.confidence + rightS.confidence) / 2,
      elbowConf: (leftE.confidence + rightE.confidence) / 2,
      noseConf: nosePoint.confidence,
      raw: List<KeyPoint>.unmodifiable(keypoints),
    );
  }

  static double weightedMean(
    List<double> values,
    List<double> weights, {
    double minConf = 0.1,
  }) {
    var totalWeight = 0.0;
    var total = 0.0;
    for (var i = 0; i < values.length; i++) {
      final weight = weights[i];
      if (weight < minConf) {
        continue;
      }
      totalWeight += weight;
      total += values[i] * weight;
    }
    return totalWeight == 0 ? double.nan : total / totalWeight;
  }
}

class SignalFilter {
  SignalFilter({this.window = 5});

  final int window;
  final List<double> _shoulder = <double>[];

  FrameSignals smooth(FrameSignals signals) {
    if (signals.shoulderY.isFinite) {
      _shoulder.add(signals.shoulderY);
      if (_shoulder.length > window) {
        _shoulder.removeAt(0);
      }
    }

    if (_shoulder.isEmpty) {
      return signals;
    }

    final mean = _shoulder.reduce((a, b) => a + b) / _shoulder.length;
    return signals.copyWith(shoulderY: mean);
  }

  void reset() {
    _shoulder.clear();
  }
}

class CounterConfig {
  const CounterConfig({
    this.windowN = 90,
    this.minCalibrationFrames,
    this.pHigh = 0.8,
    this.pLow = 0.2,
    this.thrDownPos = 0.6,
    this.thrUpPos = 0.4,
    this.mDown = 3,
    this.mUp = 3,
    this.confThr = 0.3,
    this.ampMinRatio = 0.04,
    this.freezeLimitMs = 1500,
    this.cycleTimeoutMs = 5000,
    this.frameHeight = 1280,
    this.fps = 30,
    this.minGapFrames = 8,
  });

  final int windowN;
  final int? minCalibrationFrames;
  final double pHigh;
  final double pLow;
  final double thrDownPos;
  final double thrUpPos;
  final int mDown;
  final int mUp;
  final double confThr;
  final double ampMinRatio;
  final int freezeLimitMs;
  final int cycleTimeoutMs;
  final double frameHeight;
  final double fps;
  final int minGapFrames;

  int get calibrationFrames => minCalibrationFrames ?? windowN;
  int get freezeLimitFrames =>
      math.max(1, (freezeLimitMs * fps / 1000).round());
  int get cycleTimeoutFrames =>
      math.max(1, (cycleTimeoutMs * fps / 1000).round());
}

class CounterState {
  const CounterState({
    required this.count,
    required this.phase,
    required this.frozen,
    required this.calibrated,
    this.position,
    this.low,
    this.high,
  });

  const CounterState.initial()
    : count = 0,
      phase = Phase.up,
      frozen = false,
      calibrated = false,
      position = null,
      low = null,
      high = null;

  final int count;
  final Phase phase;
  final bool frozen;
  final bool calibrated;
  final double? position;
  final double? low;
  final double? high;
}

class PushupCounter {
  PushupCounter({this.config = const CounterConfig()});

  final CounterConfig config;
  final List<double> _window = <double>[];
  var _state = const CounterState.initial();
  var _frame = 0;
  var _frozenFrames = 0;
  var _downHits = 0;
  var _upHits = 0;
  var _lastSwitchFrame = -1000000;
  var _downEnteredFrame = -1000000;

  CounterState get state => _state;

  CounterState update(FrameSignals signals) {
    final frame = signals.frame ?? _frame;
    _frame = frame + 1;

    final usable =
        signals.shoulderY.isFinite && signals.shoulderConf >= config.confThr;
    if (!usable) {
      _frozenFrames += 1;
      if (_frozenFrames > config.freezeLimitFrames) {
        _discardHalfCycle();
      }
      _state = _nextState(frozen: true);
      return _state;
    }

    _frozenFrames = 0;
    _push(signals.shoulderY);

    if (_window.length < config.calibrationFrames) {
      _state = _nextState(frozen: false, calibrated: false);
      return _state;
    }

    final low = _percentile(_window, config.pLow);
    final high = _percentile(_window, config.pHigh);
    final amplitude = high - low;
    if (amplitude < config.frameHeight * config.ampMinRatio) {
      _downHits = 0;
      _upHits = 0;
      _state = _nextState(frozen: true, calibrated: true, low: low, high: high);
      return _state;
    }

    final position = (signals.shoulderY - low) / amplitude;
    final canSwitch = frame - _lastSwitchFrame >= config.minGapFrames;
    if (canSwitch) {
      if (_state.phase == Phase.up) {
        _handleUpPhase(position, frame);
      } else {
        _handleDownPhase(position, frame);
      }
    }

    _state = _nextState(
      frozen: false,
      calibrated: true,
      position: position,
      low: low,
      high: high,
    );
    return _state;
  }

  void reset() {
    _window.clear();
    _state = const CounterState.initial();
    _frame = 0;
    _frozenFrames = 0;
    _downHits = 0;
    _upHits = 0;
    _lastSwitchFrame = -1000000;
    _downEnteredFrame = -1000000;
  }

  void _handleUpPhase(double position, int frame) {
    if (position >= config.thrDownPos) {
      _downHits += 1;
      if (_downHits >= config.mDown) {
        _state = CounterState(
          count: _state.count,
          phase: Phase.down,
          frozen: false,
          calibrated: true,
        );
        _lastSwitchFrame = frame;
        _downEnteredFrame = frame;
        _downHits = 0;
        _upHits = 0;
      }
    } else {
      _downHits = 0;
    }
  }

  void _handleDownPhase(double position, int frame) {
    if (frame - _downEnteredFrame > config.cycleTimeoutFrames) {
      _discardHalfCycle();
      return;
    }

    if (position <= config.thrUpPos) {
      _upHits += 1;
      if (_upHits >= config.mUp) {
        _state = CounterState(
          count: _state.count + 1,
          phase: Phase.up,
          frozen: false,
          calibrated: true,
        );
        _lastSwitchFrame = frame;
        _downHits = 0;
        _upHits = 0;
      }
    } else {
      _upHits = 0;
    }
  }

  void _discardHalfCycle() {
    _state = CounterState(
      count: _state.count,
      phase: Phase.up,
      frozen: true,
      calibrated: _state.calibrated,
    );
    _downHits = 0;
    _upHits = 0;
    _downEnteredFrame = -1000000;
  }

  void _push(double value) {
    _window.add(value);
    if (_window.length > config.windowN) {
      _window.removeAt(0);
    }
  }

  CounterState _nextState({
    required bool frozen,
    bool? calibrated,
    double? position,
    double? low,
    double? high,
  }) {
    return CounterState(
      count: _state.count,
      phase: _state.phase,
      frozen: frozen,
      calibrated: calibrated ?? _state.calibrated,
      position: position,
      low: low,
      high: high,
    );
  }

  static double _percentile(List<double> values, double p) {
    final sorted = values.toList()..sort();
    final pos = (sorted.length - 1) * p;
    final low = pos.floor();
    final high = pos.ceil();
    if (low == high) {
      return sorted[low];
    }
    return sorted[low] * (high - pos) + sorted[high] * (pos - low);
  }
}
