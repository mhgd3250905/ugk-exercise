import '../pushup_domain.dart';

/// Single-responsibility assembly of the pushup counting pipeline:
/// keypoint → signal → smooth → count.
///
/// This encapsulates the `SignalExtractor → SignalFilter → PushupCounter`
/// chain that was previously hand-written (inconsistently) in both the live
/// workout page and the offline replay tab. Wrist stability is *not* owned
/// here — it is a gating signal computed by the caller (WristAnchor in the
/// live path, or constant `true` in offline replay) and passed into
/// [process], so the pipeline stays free of ready-state concerns.
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

  /// Advance the pipeline one frame. [handsStable] is the caller's wrist-gate
  /// verdict for this frame; it flows into `FrameSignals.handsStable` which the
  /// counter requires before counting.
  CounterState process(
    List<KeyPoint> keypoints, {
    bool handsStable = true,
  }) {
    final signals = _filter.smooth(
      _extractor.toSignals(keypoints).copyWith(handsStable: handsStable),
    );
    _lastSignals = signals;
    return _counter.update(signals);
  }

  /// Reset the filter and counter (but not the count-free extractor, which is
  /// stateless). Called on a fresh session or when re-entering the ready state.
  void reset() {
    _filter.reset();
    _counter.reset();
  }
}
