import '../pushup_domain.dart';

/// Single-responsibility assembly of the pushup counting pipeline:
/// keypoint → signal → count.
///
/// [PushupCounter] owns the single smoothing stage. Wrist stability is *not*
/// owned here: the live caller may attach its WristAnchor verdict for
/// diagnostics, but close-range torso filtering and counting do not gate on it.
///
/// See docs/modules/pushup-pipeline.md and docs/modules/recognition.md.
class PushupPipeline {
  PushupPipeline({CounterConfig config = const CounterConfig()})
    : _counter = PushupCounter(config: config);

  final SignalExtractor _extractor = const SignalExtractor();
  final PushupCounter _counter;
  FrameSignals? _lastSignals;
  double? _readyTopY;
  double? _readyGroundSpan;
  double? _minDownY;

  /// Coordinate height used when the current pixel thresholds were tuned.
  static const double referenceSourceHeight =
      SignalExtractor.referenceFrameHeight;

  /// Current rep count.
  int get count => _counter.state.count;

  /// The signals from the most recent [process] call, for diagnostics.
  FrameSignals? get lastSignals => _lastSignals;

  double get requiredDepthRatio => _counter.config.readyDepthRatio;
  double? get readyTopY => _readyTopY;
  double? get readyGroundSpan => _readyGroundSpan;
  double? get requiredDownY => _minDownY;
  double? get lastDepthRatio {
    final top = _readyTopY;
    final span = _readyGroundSpan;
    final torso = _lastSignals?.torsoY;
    if (top == null || span == null || torso == null || !torso.isFinite) {
      return null;
    }
    return (torso - top) / span;
  }

  /// Calibrate live motion depth from the strict ready pose. Both wrists must
  /// be independently visible; the larger top-to-wrist span is used so one
  /// wrist is never averaged into the other.
  bool calibrateReadyDepth(
    List<KeyPoint> keypoints, {
    double sourceHeight = referenceSourceHeight,
  }) {
    if (keypoints.length < 17 || !sourceHeight.isFinite || sourceHeight <= 0) {
      return false;
    }
    final normalized = _normalize(keypoints, sourceHeight);
    final signals = _extractor.toSignals(normalized);
    final top = signals.torsoY;
    final leftWrist = normalized[SignalExtractor.leftWrist];
    final rightWrist = normalized[SignalExtractor.rightWrist];
    if (top == null ||
        !top.isFinite ||
        leftWrist.confidence < _counter.config.confThr ||
        rightWrist.confidence < _counter.config.confThr) {
      return false;
    }
    final leftSpan = leftWrist.y - top;
    final rightSpan = rightWrist.y - top;
    if (!leftSpan.isFinite ||
        !rightSpan.isFinite ||
        leftSpan <= 0 ||
        rightSpan <= 0) {
      return false;
    }
    final span = leftSpan > rightSpan ? leftSpan : rightSpan;
    _readyTopY = top;
    _readyGroundSpan = span;
    _minDownY = top + _counter.config.readyDepthRatio * span;
    return true;
  }

  /// Advance the pipeline one frame. [handsStable] is retained as diagnostic
  /// metadata only; missing or perspective-shifted wrists do not freeze motion.
  CounterState process(
    List<KeyPoint> keypoints, {
    bool handsStable = true,
    double sourceHeight = referenceSourceHeight,
    RepCompletionDecision repCompletionDecision = RepCompletionDecision.allow,
  }) {
    if (!sourceHeight.isFinite || sourceHeight <= 0) {
      throw ArgumentError.value(
        sourceHeight,
        'sourceHeight',
        'must be positive',
      );
    }
    final normalized = _normalize(keypoints, sourceHeight);
    final signals = _extractor
        .toSignals(normalized)
        .copyWith(handsStable: handsStable);
    _lastSignals = signals;
    final readyDepthPx = _readyGroundSpan == null
        ? null
        : _counter.config.readyDepthRatio * _readyGroundSpan!;
    final minAmplitudePx =
        readyDepthPx != null && readyDepthPx < _counter.config.ampMinPx
        ? (readyDepthPx < _counter.config.calibratedAmpMinPx
              ? _counter.config.calibratedAmpMinPx
              : readyDepthPx)
        : null;
    return _counter.update(
      signals,
      minDownY: _minDownY,
      minAmplitudePx: minAmplitudePx,
      repCompletionDecision: repCompletionDecision,
    );
  }

  /// Reset the counter for a fresh session.
  void reset() {
    _counter.reset();
    _lastSignals = null;
    _clearReadyDepth();
  }

  /// Reset transient tracking after a camera/pose interruption while preserving
  /// the accumulated workout count.
  void resetTracking({int? count}) {
    _counter.reset(count: count ?? _counter.state.count);
    _lastSignals = null;
    _clearReadyDepth();
  }

  List<KeyPoint> _normalize(List<KeyPoint> keypoints, double sourceHeight) {
    final scale = referenceSourceHeight / sourceHeight;
    return scale == 1
        ? keypoints
        : [
            for (final point in keypoints)
              KeyPoint(
                index: point.index,
                x: point.x * scale,
                y: point.y * scale,
                confidence: point.confidence,
              ),
          ];
  }

  void _clearReadyDepth() {
    _readyTopY = null;
    _readyGroundSpan = null;
    _minDownY = null;
  }
}
