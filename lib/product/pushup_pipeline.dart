import '../pushup_domain.dart';

/// Single-responsibility assembly of the pushup counting pipeline:
/// keypoint → signal → smooth → count.
///
/// This encapsulates the `SignalExtractor → SignalFilter → PushupCounter`
/// chain that was previously hand-written (inconsistently) in both the live
/// workout page and the offline replay tab. Wrist stability is *not* owned
/// here: the live caller may attach its WristAnchor verdict for diagnostics,
/// but close-range torso filtering and counting do not gate on it.
///
/// See docs/modules/pushup-pipeline.md and docs/modules/recognition.md.
class PushupPipeline {
  PushupPipeline({CounterConfig config = const CounterConfig()})
    : _counter = PushupCounter(config: config);

  final SignalExtractor _extractor = const SignalExtractor();
  final SignalFilter _filter = SignalFilter(window: 5);
  final PushupCounter _counter;
  FrameSignals? _lastSignals;

  /// Current rep count.
  int get count => _counter.state.count;

  /// The smoothed signals from the most recent [process] call, for diagnostics.
  FrameSignals? get lastSignals => _lastSignals;

  /// Advance the pipeline one frame. [handsStable] is retained as diagnostic
  /// metadata only; missing or perspective-shifted wrists do not freeze motion.
  CounterState process(List<KeyPoint> keypoints, {bool handsStable = true}) {
    final signals = _filter.smooth(
      _extractor.toSignals(keypoints).copyWith(handsStable: handsStable),
    );
    _lastSignals = signals;
    return _counter.update(signals);
  }

  /// Reset the filter and counter (but not the count-free extractor, which is
  /// stateless). Called on a fresh session.
  void reset() {
    _filter.reset();
    _counter.reset();
    _lastSignals = null;
  }

  /// Reset transient tracking after a camera/pose interruption while preserving
  /// the accumulated workout count.
  void resetTracking({int? count}) {
    _filter.reset();
    _counter.reset(count: count ?? _counter.state.count);
    _lastSignals = null;
  }
}
