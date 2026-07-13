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

  /// Coordinate height used when the current pixel thresholds were tuned.
  static const double referenceSourceHeight =
      SignalExtractor.referenceFrameHeight;

  /// Current rep count.
  int get count => _counter.state.count;

  /// The signals from the most recent [process] call, for diagnostics.
  FrameSignals? get lastSignals => _lastSignals;

  /// Advance the pipeline one frame. [handsStable] is retained as diagnostic
  /// metadata only; missing or perspective-shifted wrists do not freeze motion.
  CounterState process(
    List<KeyPoint> keypoints, {
    bool handsStable = true,
    double sourceHeight = referenceSourceHeight,
  }) {
    if (!sourceHeight.isFinite || sourceHeight <= 0) {
      throw ArgumentError.value(
        sourceHeight,
        'sourceHeight',
        'must be positive',
      );
    }
    final scale = referenceSourceHeight / sourceHeight;
    final normalized = scale == 1
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
    final signals = _extractor
        .toSignals(normalized)
        .copyWith(handsStable: handsStable);
    _lastSignals = signals;
    return _counter.update(signals);
  }

  /// Reset the counter for a fresh session.
  void reset() {
    _counter.reset();
    _lastSignals = null;
  }

  /// Reset transient tracking after a camera/pose interruption while preserving
  /// the accumulated workout count.
  void resetTracking({int? count}) {
    _counter.reset(count: count ?? _counter.state.count);
    _lastSignals = null;
  }
}
