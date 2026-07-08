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

/// Configuration for the peak/valley pushup counter.
///
/// The counter is shape-based and does not depend on frame rate: all timing
/// knobs from the previous state-machine implementation are retained only for
/// backwards compatibility (the App still constructs `CounterConfig(frameHeight:
/// 1280, fps: 30)`) but are no longer consulted.
class CounterConfig {
  const CounterConfig({
    // --- New, shape-based parameters ---
    // Minimum absolute swing (px) required to accept a rep. Tuned so that
    // Gaussian noise of ±20px (5th-95th percentile range ≈ 25-50px) can never
    // reach it, while real pushups always do (video4's smallest rep swing is
    // ~106px, leaving a comfortable margin). 80px also rejects the partial
    // warm-up half-rep at the start of video1 (~56px swing).
    this.ampMinPx = 80,
    // Minimum swing as a fraction of the robust signal amplitude.
    // `THR = max(thrRatio * amp, ampMinPx)`.
    this.thrRatio = 0.5,
    // Hysteresis band as fractions of amplitude, measured from the low
    // percentile. ENTER_DOWN = pLow + hystHigh * amp; ENTER_UP = pLow +
    // hystLow * amp. The dead band (hystHigh - hystLow) prevents chatter.
    this.hystHigh = 0.65,
    this.hystLow = 0.35,
    // Robust amplitude percentiles (ignore tracking outliers).
    this.pLow = 0.05,
    this.pHigh = 0.95,
    // Minimum confidence for a frame to feed the counter.
    this.confThr = 0.3,

    // --- Legacy fields (retained for call-site compatibility, unused) ---
    @Deprecated('Unused by the peak/valley counter; kept for compatibility.')
    this.windowN = 90,
    @Deprecated('Unused by the peak/valley counter; kept for compatibility.')
    this.minCalibrationFrames,
    @Deprecated('Unused by the peak/valley counter; kept for compatibility.')
    this.thrDownPos = 0.6,
    @Deprecated('Unused by the peak/valley counter; kept for compatibility.')
    this.thrUpPos = 0.4,
    @Deprecated('Unused by the peak/valley counter; kept for compatibility.')
    this.mDown = 3,
    @Deprecated('Unused by the peak/valley counter; kept for compatibility.')
    this.mUp = 3,
    @Deprecated('Unused by the peak/valley counter; kept for compatibility.')
    this.ampMinRatio = 0.04,
    @Deprecated('Unused by the peak/valley counter; kept for compatibility.')
    this.freezeLimitMs = 1500,
    @Deprecated('Unused by the peak/valley counter; kept for compatibility.')
    this.cycleTimeoutMs = 5000,
    this.frameHeight = 1280,
    this.fps = 30,
    @Deprecated('Unused by the peak/valley counter; kept for compatibility.')
    this.minGapFrames = 8,
  });

  final double ampMinPx;
  final double thrRatio;
  final double hystHigh;
  final double hystLow;
  final double pLow;
  final double pHigh;
  final double confThr;

  // ignore: deprecated_member_use_from_same_package
  final int windowN;
  // ignore: deprecated_member_use_from_same_package
  final int? minCalibrationFrames;
  // ignore: deprecated_member_use_from_same_package
  final double thrDownPos;
  // ignore: deprecated_member_use_from_same_package
  final double thrUpPos;
  // ignore: deprecated_member_use_from_same_package
  final int mDown;
  // ignore: deprecated_member_use_from_same_package
  final int mUp;
  // ignore: deprecated_member_use_from_same_package
  final double ampMinRatio;
  // ignore: deprecated_member_use_from_same_package
  final int freezeLimitMs;
  // ignore: deprecated_member_use_from_same_package
  final int cycleTimeoutMs;
  final double frameHeight;
  final double fps;
  // ignore: deprecated_member_use_from_same_package
  final int minGapFrames;
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

/// Peak/valley pushup counter.
///
/// Counts reps by detecting an up→down→up shape in the (smoothed) shoulder_y
/// signal. Unlike the previous window-percentile state machine, this counter:
///   * is purely shape-based — it does not convert time to frame counts, so it
///     works at any fps (the project fixes 30fps, but the algorithm is agnostic);
///   * requires a meaningful swing via an adaptive threshold with an absolute
///     floor (`ampMinPx`), which rejects ±20px noise while counting fast reps;
///   * uses an armed/reset design (no global phase latch) so it is immune to
///     cold-start phase ambiguity: a rep is counted whenever the signal rises
///     into the DOWN band with a sufficient swing from the lowest point since
///     the previous rep, and the detector then waits to return to the UP band
///     before the next rep can count.
///
/// Public API (`update`/`reset`/`state`) is unchanged from the previous
/// implementation; `CounterState.count` is what callers consume.
class PushupCounter {
  PushupCounter({this.config = const CounterConfig()});

  final CounterConfig config;

  // Raw shoulder_y samples accepted so far (robust percentiles are computed
  // over the full history; pushups are short relative to memory and the cost
  // is negligible for offline replay + 30fps live use).
  final List<double> _samples = <double>[];
  // Rolling window feeding the median filter.
  final List<double> _medianBuf = <double>[];

  CounterState _state = const CounterState.initial();
  // Whether the detector is allowed to count the next rep. Set false right
  // after a count and re-armed once the signal returns to the UP band, so a
  // single descent cannot register more than one rep.
  bool _armed = true;
  // Lowest smoothed y seen since the last count (or since start). The rep's
  // swing is measured from this point, so each rep is judged on its own merit
  // rather than against a global valley.
  double? _valleySinceCount;

  CounterState get state => _state;

  CounterState update(FrameSignals signals) {
    final usable =
        signals.shoulderY.isFinite && signals.shoulderConf >= config.confThr;
    if (!usable) {
      // Hold state; missing frames do not advance or roll back a rep.
      _state = CounterState(
        count: _state.count,
        phase: _state.phase,
        frozen: true,
        calibrated: _state.calibrated,
        position: _state.position,
        low: _state.low,
        high: _state.high,
      );
      return _state;
    }

    _samples.add(signals.shoulderY);
    final smoothed = _pushMedian(signals.shoulderY);

    // Robust amplitude from full-history percentiles (outlier-resistant).
    final low = _percentile(_samples, config.pLow);
    final high = _percentile(_samples, config.pHigh);
    final amp = high - low;

    if (amp < config.ampMinPx) {
      // Signal not yet (or no longer) meaningful — below the absolute floor.
      // This covers both the stationary case and the cold-start warm-up where
      // running percentiles are not yet representative. Keep tracking the
      // recent low but do not evaluate a rep.
      _trackLow(smoothed);
      _state = CounterState(
        count: _state.count,
        phase: _state.phase,
        frozen: false,
        calibrated: amp >= 1e-6,
        position: amp < 1e-6 ? 0 : (smoothed - low) / amp,
        low: low,
        high: high,
      );
      return _state;
    }

    final thr = math.max(config.thrRatio * amp, config.ampMinPx);
    final enterDown = low + config.hystHigh * amp;
    final enterUp = low + config.hystLow * amp;
    final position = (smoothed - low) / amp;

    final counted = _step(smoothed, enterDown, enterUp, thr);

    _state = CounterState(
      count: _state.count,
      phase: counted ? Phase.down : _state.phase,
      frozen: false,
      calibrated: true,
      position: position,
      low: low,
      high: high,
    );
    return _state;
  }

  void reset() {
    _samples.clear();
    _medianBuf.clear();
    _state = const CounterState.initial();
    _armed = true;
    _valleySinceCount = null;
  }

  /// Core detector step. Returns true if a rep was counted on this frame.
  ///
  /// While armed, a rep is counted when the signal rises into the DOWN band
  /// ([enterDown]) with a swing from the recent low no smaller than [thr]. The
  /// detector then disarms until the signal returns to the UP band
  /// ([enterUp]), at which point it re-arms and restarts the low tracking.
  bool _step(double y, double enterDown, double enterUp, double thr) {
    _trackLow(y);
    if (_armed) {
      final valley = _valleySinceCount;
      if (y >= enterDown && valley != null && (y - valley) >= thr) {
        _state = CounterState(
          count: _state.count + 1,
          phase: Phase.down,
          frozen: false,
          calibrated: true,
        );
        _armed = false;
        return true;
      }
    } else if (y <= enterUp) {
      // Returned to the up position: allow the next rep and restart low
      // tracking from here.
      _armed = true;
      _valleySinceCount = y;
    }
    return false;
  }

  void _trackLow(double y) {
    if (_valleySinceCount == null || y < _valleySinceCount!) {
      _valleySinceCount = y;
    }
  }

  /// Centered running median with window=5 (the same width used by the App's
  /// `SignalFilter`), applied locally before detection to suppress spike noise.
  double _pushMedian(double value) {
    _medianBuf.add(value);
    if (_medianBuf.length > 5) {
      _medianBuf.removeAt(0);
    }
    final sorted = _medianBuf.toList()..sort();
    return sorted[sorted.length ~/ 2];
  }

  static double _percentile(List<double> values, double p) {
    if (values.isEmpty) return double.nan;
    final sorted = values.toList()..sort();
    final pos = (sorted.length - 1) * p;
    final lo = pos.floor();
    final hi = pos.ceil();
    if (lo == hi) {
      return sorted[lo];
    }
    return sorted[lo] * (hi - pos) + sorted[hi] * (pos - lo);
  }
}
