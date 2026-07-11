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
    this.elbowAngle,
    this.pressDepthY,
    this.torsoY,
    this.handsSupported = true,
    this.handsStable = true,
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
  final double? elbowAngle;
  final double? pressDepthY;

  /// Head+shoulder vertical position: the single motion signal for a pushup.
  ///
  /// The head, neck and shoulders move as one rigid body during a press, so
  /// averaging them is geometrically sound — unlike averaging the two wrists,
  /// which are independent support points. A raised hand does not move the
  /// torso, so this signal cannot fake a press the way `pressDepthY` can.
  final double? torsoY;
  final bool handsSupported;

  /// WristAnchor's diagnostic verdict for this frame. Close-range counting does
  /// not gate torso motion on this value because invisible/jittery wrists are
  /// expected after the strict ready pose has been established.
  final bool handsStable;
  final double shoulderConf;
  final double elbowConf;
  final double noseConf;
  final List<KeyPoint> raw;

  FrameSignals copyWith({
    double? shoulderY,
    double? headY,
    double? elbowLateral,
    double? elbowAngle,
    double? pressDepthY,
    double? torsoY,
    bool? handsSupported,
    bool? handsStable,
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
      elbowAngle: elbowAngle ?? this.elbowAngle,
      pressDepthY: pressDepthY ?? this.pressDepthY,
      torsoY: torsoY ?? this.torsoY,
      handsSupported: handsSupported ?? this.handsSupported,
      handsStable: handsStable ?? this.handsStable,
      shoulderConf: shoulderConf ?? this.shoulderConf,
      elbowConf: elbowConf ?? this.elbowConf,
      noseConf: noseConf ?? this.noseConf,
      raw: raw,
    );
  }
}

/// COCO-17 keypoint names, in index order. Shared protocol for the inference
/// decoder, the keypoint CSV log, and the performance report — living in the
/// domain so downstream layers depend upward on the domain, not sideways on
/// each other (this used to live in inference/keypoint_log.dart, which forced
/// report/ to depend on inference/).
const keypointNames = [
  'nose',
  'left_eye',
  'right_eye',
  'left_ear',
  'right_ear',
  'left_shoulder',
  'right_shoulder',
  'left_elbow',
  'right_elbow',
  'left_wrist',
  'right_wrist',
  'left_hip',
  'right_hip',
  'left_knee',
  'right_knee',
  'left_ankle',
  'right_ankle',
];

class SignalExtractor {
  const SignalExtractor({this.minConf = 0.1});

  /// Pixel-coordinate height used by the existing tuned thresholds and replay
  /// fixtures. Live frames are normalized to this height before extraction.
  static const double referenceFrameHeight = 1280;

  static const int nose = 0;
  static const int leftShoulder = 5;
  static const int rightShoulder = 6;
  static const int leftElbow = 7;
  static const int rightElbow = 8;
  static const int leftWrist = 9;
  static const int rightWrist = 10;
  static const int leftHip = 11;
  static const int rightHip = 12;
  static const double wristSupportMarginPx = 20;

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
    final leftW = keypoints[leftWrist];
    final rightW = keypoints[rightWrist];
    final nosePoint = keypoints[nose];

    final shoulderY = weightedMean(
      [leftS.y, rightS.y],
      [leftS.confidence, rightS.confidence],
      minConf: minConf,
    );
    final wristY = weightedMean(
      [leftW.y, rightW.y],
      [leftW.confidence, rightW.confidence],
      minConf: minConf,
    );
    final elbowUsable =
        leftE.confidence >= minConf && rightE.confidence >= minConf;
    final leftAngle = angleAt(a: leftS, b: leftE, c: leftW, minConf: minConf);
    final rightAngle = angleAt(
      a: rightS,
      b: rightE,
      c: rightW,
      minConf: minConf,
    );
    final elbowAngle = weightedMean(
      [leftAngle ?? 0, rightAngle ?? 0],
      [
        leftAngle == null
            ? 0
            : (leftS.confidence + leftE.confidence + leftW.confidence) / 3,
        rightAngle == null
            ? 0
            : (rightS.confidence + rightE.confidence + rightW.confidence) / 3,
      ],
      minConf: minConf,
    );

    // Head + shoulders are one rigid body during a press, so they may be
    // averaged into a single motion signal. Wrists must never feed this — they
    // are independent support points, and averaging them is exactly what let a
    // raised hand fake a press (one wrist moves, the average moves, the
    // shoulder-wrist difference moves in the same direction as a real press).
    final torsoY = weightedMean(
      [leftS.y, rightS.y, nosePoint.y],
      [leftS.confidence, rightS.confidence, nosePoint.confidence],
      minConf: minConf,
    );

    return FrameSignals(
      shoulderY: shoulderY,
      headY: nosePoint.confidence >= minConf ? nosePoint.y : null,
      elbowLateral: elbowUsable ? (leftE.x - rightE.x).abs() : null,
      elbowAngle: elbowAngle.isFinite ? elbowAngle : null,
      pressDepthY: shoulderY.isFinite && wristY.isFinite
          ? shoulderY - wristY
          : null,
      torsoY: torsoY.isFinite ? torsoY : null,
      handsSupported: wristsNotClearlyRaised(keypoints),
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

  static double? angleAt({
    required KeyPoint a,
    required KeyPoint b,
    required KeyPoint c,
    double minConf = 0.1,
  }) {
    if (a.confidence < minConf ||
        b.confidence < minConf ||
        c.confidence < minConf) {
      return null;
    }
    final abx = a.x - b.x;
    final aby = a.y - b.y;
    final cbx = c.x - b.x;
    final cby = c.y - b.y;
    final ab = math.sqrt(abx * abx + aby * aby);
    final cb = math.sqrt(cbx * cbx + cby * cby);
    if (ab == 0 || cb == 0) {
      return null;
    }
    final cos = ((abx * cbx + aby * cby) / (ab * cb)).clamp(-1.0, 1.0);
    return math.acos(cos) * 180 / math.pi;
  }

  static bool wristsBelowShoulders(
    List<KeyPoint> keypoints, {
    double minConf = 0.3,
    double marginPx = wristSupportMarginPx,
  }) {
    if (keypoints.length < 17) {
      return false;
    }
    bool supported(int wristIndex, int shoulderIndex) {
      final wrist = keypoints[wristIndex];
      final shoulder = keypoints[shoulderIndex];
      if (wrist.confidence < minConf || shoulder.confidence < minConf) {
        return true;
      }
      return wrist.y - shoulder.y >= marginPx;
    }

    return supported(leftWrist, leftShoulder) &&
        supported(rightWrist, rightShoulder);
  }

  /// Motion-stage support check: only confidently visible evidence that a
  /// wrist rose clearly above its shoulder contradicts the ready calibration.
  /// A wrist near the shoulder line may be a boundary-clamped prediction when
  /// the arm leaves frame, so it is unknown rather than a reason to freeze.
  static bool wristsNotClearlyRaised(
    List<KeyPoint> keypoints, {
    double minConf = 0.3,
    double marginPx = wristSupportMarginPx,
  }) {
    if (keypoints.length < 17) {
      return false;
    }
    bool notRaised(int wristIndex, int shoulderIndex) {
      final wrist = keypoints[wristIndex];
      final shoulder = keypoints[shoulderIndex];
      if (wrist.confidence < minConf || shoulder.confidence < minConf) {
        return true;
      }
      return wrist.y >= shoulder.y - marginPx;
    }

    return notRaised(leftWrist, leftShoulder) &&
        notRaised(rightWrist, rightShoulder);
  }
}

class SignalFilter {
  SignalFilter({this.window = 5});

  final int window;
  final List<double> _shoulder = <double>[];
  final List<double> _pressDepth = <double>[];
  final List<double> _torso = <double>[];

  FrameSignals smooth(FrameSignals signals) {
    if (signals.handsSupported && signals.shoulderY.isFinite) {
      _shoulder.add(signals.shoulderY);
      if (_shoulder.length > window) {
        _shoulder.removeAt(0);
      }
    }
    final pressDepth = signals.pressDepthY;
    if (signals.handsSupported && pressDepth != null && pressDepth.isFinite) {
      _pressDepth.add(pressDepth);
      if (_pressDepth.length > window) {
        _pressDepth.removeAt(0);
      }
    }
    final torso = signals.torsoY;
    if (signals.handsSupported && torso != null && torso.isFinite) {
      _torso.add(torso);
      if (_torso.length > window) {
        _torso.removeAt(0);
      }
    }

    if (_shoulder.isEmpty) {
      return signals;
    }

    final mean = _shoulder.reduce((a, b) => a + b) / _shoulder.length;
    final depthMean = _pressDepth.isEmpty
        ? null
        : _pressDepth.reduce((a, b) => a + b) / _pressDepth.length;
    final torsoMean = _torso.isEmpty
        ? null
        : _torso.reduce((a, b) => a + b) / _torso.length;
    return signals.copyWith(
      shoulderY: mean,
      pressDepthY: depthMean,
      torsoY: torsoMean,
    );
  }

  void reset() {
    _shoulder.clear();
    _pressDepth.clear();
    _torso.clear();
  }
}

/// Configuration for the peak/valley pushup counter.
///
/// The counter is shape-based. Motion thresholds are in pixels/degrees; the
/// recent-history bound is in accepted samples. See docs/modules/recognition.md
/// §7 for the tuning rationale of each.
class CounterConfig {
  const CounterConfig({
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
    // ponytail: bounded recent history avoids long rests diluting the next rep;
    // tune this only if real processed-frame rates show the 4s@30fps window is
    // too short or too long.
    this.sampleWindow = 120,
    // Minimum confidence for a frame to feed the counter.
    this.confThr = 0.3,
    // When elbow evidence is visible during both the dip and return, it may
    // veto a straight/fixed-arm torso bob. Missing elbow evidence is exempt.
    this.elbowBentMaxDegrees = 145,
    this.elbowAngleDeltaMinDegrees = 25,
  });

  final double ampMinPx;
  final double thrRatio;
  final double hystHigh;
  final double hystLow;
  final double pLow;
  final double pHigh;
  final int sampleWindow;
  final double confThr;
  final double elbowBentMaxDegrees;
  final double elbowAngleDeltaMinDegrees;
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
/// Counts reps by detecting an up→down→up shape in the (smoothed) torso_y
/// signal. Unlike the previous window-percentile state machine, this counter:
///   * uses a bounded recent-sample window, so long waits do not dilute the next
///     rep and percentile cost does not grow for the whole workout;
///   * requires a meaningful swing via an adaptive threshold with an absolute
///     floor (`ampMinPx`), which rejects ±20px noise while counting fast reps;
///   * arms on descent into the DOWN band and counts only after a sufficient
///     return to the UP band.
///
/// Public API (`update`/`reset`/`state`) is unchanged from the previous
/// implementation; `CounterState.count` is what callers consume.
class PushupCounter {
  PushupCounter({this.config = const CounterConfig()});

  final CounterConfig config;

  // Recent accepted torso samples used for robust amplitude percentiles.
  final List<double> _samples = <double>[];
  // Rolling window feeding the median filter.
  final List<double> _medianBuf = <double>[];

  CounterState _state = const CounterState.initial();
  // Whether the detector is allowed to count the next rep. Set false right
  // after a count and re-armed once the signal returns to the UP band, so a
  // single descent cannot register more than one rep.
  bool _armed = true;
  Phase _phase = Phase.up;
  // Minimum confidently-visible elbow angle during the current dip. Arm
  // keypoints commonly leave the frame at close range, so missing evidence is
  // not a failure. When the elbow is visible both during the dip and on return,
  // it may veto an obviously straight/fixed-arm torso bob.
  double? _minDipElbowAngle;
  // Deepest point (largest y = closest to the floor) reached during the current
  // dip, while disarmed. The rep's swing is measured from this peak back up to
  // the up-return threshold.
  double? _dipPeak;

  CounterState get state => _state;

  CounterState update(FrameSignals signals) {
    // Motion-stage gate: once the ready state has calibrated the wrist support
    // baseline, a pushup is simply the head+shoulders pressing toward that
    // fixed line and back. The torso signal (torsoY) plus confident shoulders
    // is enough to count. We keep handsSupported as a visible contradiction
    // check so a confidently detected hand raised to the face still fails, but
    // low-confidence/invisible wrists are exempt.
    // no longer require:
    //   * handsStable (WristAnchor drift gate) — it misfired at close range,
    //     treating perspective-amplified jitter as "hand left support";
    //   * elbowAngle / elbowConf — elbows leave the frame first when close.
    // Elbows are optional evidence: when visible during both dip and return
    // they can reject a straight/fixed-arm bob, but missing arms never veto a
    // complete torso cycle.
    final usable =
        signals.torsoY != null &&
        signals.torsoY!.isFinite &&
        signals.handsSupported &&
        signals.shoulderConf >= config.confThr;
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

    final motionY = signals.torsoY!;
    _samples.add(motionY);
    if (_samples.length > config.sampleWindow) {
      _samples.removeAt(0);
    }
    final smoothed = _pushMedian(motionY);
    // Robust amplitude from recent percentiles (outlier-resistant).
    final low = _percentile(_samples, config.pLow);
    final high = _percentile(_samples, config.pHigh);
    final amp = high - low;

    if (amp < config.ampMinPx) {
      // Signal not yet (or no longer) meaningful — below the absolute floor.
      // This covers both the stationary case and the cold-start warm-up where
      // running percentiles are not yet representative. Do not evaluate a rep.
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

    _step(
      smoothed,
      enterDown,
      enterUp,
      thr,
      signals.elbowAngle,
      signals.elbowConf,
    );

    _state = CounterState(
      count: _state.count,
      phase: _phase,
      frozen: false,
      calibrated: true,
      position: position,
      low: low,
      high: high,
    );
    return _state;
  }

  void reset({int count = 0}) {
    _samples.clear();
    _medianBuf.clear();
    _state = count == 0
        ? const CounterState.initial()
        : CounterState(
            count: count,
            phase: Phase.up,
            frozen: false,
            calibrated: false,
          );
    _armed = true;
    _phase = Phase.up;
    _minDipElbowAngle = null;
    _dipPeak = null;
  }

  /// Advance the core detector by one usable frame.
  ///
  /// Phase machine (counts on the UP-return, not the DOWN-descent):
  ///   * armed: the user is in the up position. We watch for them to descend
  ///     past [enterDown]; once they do, we track the deepest point of the dip
  ///     ([_dipPeak]) and any visible elbow evidence, then disarm.
  ///   * disarmed: the user is down (or coming back up). When the signal rises
  ///     back above [enterUp] with a sufficient swing from the valley, the rep
  ///     counts unless visible elbow evidence clearly contradicts it.
  ///
  /// Counting on the up-return (not the down-descent) is deliberate: the
  /// up-return completes the full motion cycle. Elbows and wrists may remain
  /// outside the frame at close range, so neither is required to count.
  void _step(
    double y,
    double enterDown,
    double enterUp,
    double thr,
    double? elbowAngle,
    double elbowConf,
  ) {
    if (_armed) {
      // Watch for the descent into the down band; then start tracking the dip.
      if (y >= enterDown) {
        _dipPeak = y;
        _minDipElbowAngle = null;
        _trackDipElbow(elbowAngle, elbowConf);
        _armed = false;
        _phase = Phase.down;
      }
      return;
    }
    _trackDipElbow(elbowAngle, elbowConf);
    // Disarmed: we are in/after a dip. Track the deepest point (largest y).
    if (_dipPeak == null || y > _dipPeak!) {
      _dipPeak = y;
    }
    final peak = _dipPeak;
    // Count on the up-return: signal rose back above enterUp with a sufficient
    // swing from the deepest point of the dip.
    if (y <= enterUp && peak != null && (peak - y) >= thr) {
      final counted = _elbowAllowsCount(elbowAngle, elbowConf);
      // Either way, this dip is resolved: re-arm for the next rep.
      _armed = true;
      _phase = Phase.up;
      _dipPeak = null;
      _minDipElbowAngle = null;
      if (counted) {
        _state = CounterState(
          count: _state.count + 1,
          phase: Phase.up,
          frozen: false,
          calibrated: true,
        );
        return;
      }
    }
  }

  void _trackDipElbow(double? angle, double confidence) {
    if (angle == null || confidence < config.confThr) {
      return;
    }
    if (_minDipElbowAngle == null || angle < _minDipElbowAngle!) {
      _minDipElbowAngle = angle;
    }
  }

  bool _elbowAllowsCount(double? returnAngle, double returnConfidence) {
    final minAngle = _minDipElbowAngle;
    if (minAngle == null ||
        returnAngle == null ||
        returnConfidence < config.confThr) {
      return true;
    }
    return minAngle <= config.elbowBentMaxDegrees &&
        returnAngle - minAngle >= config.elbowAngleDeltaMinDegrees;
  }

  /// Trailing running median with window=5, applied locally before detection to
  /// suppress spike noise.
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
