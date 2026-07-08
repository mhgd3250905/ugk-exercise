class PerfSnapshot {
  const PerfSnapshot({
    required this.preprocessMs,
    required this.inferMs,
    required this.e2eMs,
    required this.meanPreprocessMs,
    required this.meanInferMs,
    required this.meanE2eMs,
    required this.p95PreprocessMs,
    required this.p95InferMs,
    required this.p95E2eMs,
    required this.fps,
    required this.uiFps,
  });

  final int preprocessMs;
  final int inferMs;
  final int e2eMs;
  final double meanPreprocessMs;
  final double meanInferMs;
  final double meanE2eMs;
  final int p95PreprocessMs;
  final int p95InferMs;
  final int p95E2eMs;
  final double fps;
  final double uiFps;
}

class PerformanceMeter {
  PerformanceMeter({this.window = 30});

  final int window;
  final _preprocess = <int>[];
  final _infer = <int>[];
  final _e2e = <int>[];
  final _uiFrames = <int>[];
  var _lastPreprocess = 0;
  var _lastInfer = 0;

  void recordPreprocess(int ms) {
    _lastPreprocess = ms;
    _push(_preprocess, ms);
  }

  void recordInfer(int ms) {
    _lastInfer = ms;
    _push(_infer, ms);
    _push(_e2e, _lastPreprocess + ms);
  }

  void recordUiFrame([int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    _uiFrames.add(now);
    _uiFrames.removeWhere((time) => now - time > 1000);
  }

  PerfSnapshot get snapshot {
    final e2e = _lastPreprocess + _lastInfer;
    final meanE2e = _mean(_e2e);
    return PerfSnapshot(
      preprocessMs: _lastPreprocess,
      inferMs: _lastInfer,
      e2eMs: e2e,
      meanPreprocessMs: _mean(_preprocess),
      meanInferMs: _mean(_infer),
      meanE2eMs: meanE2e,
      p95PreprocessMs: _p95(_preprocess),
      p95InferMs: _p95(_infer),
      p95E2eMs: _p95(_e2e),
      fps: meanE2e == 0 ? 0 : 1000 / meanE2e,
      uiFps: _uiFrames.length.toDouble(),
    );
  }

  void reset() {
    _preprocess.clear();
    _infer.clear();
    _e2e.clear();
    _uiFrames.clear();
    _lastPreprocess = 0;
    _lastInfer = 0;
  }

  void _push(List<int> values, int value) {
    values.add(value);
    if (values.length > window) {
      values.removeAt(0);
    }
  }
}

double _mean(List<int> values) {
  return values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
}

int _p95(List<int> values) {
  if (values.isEmpty) {
    return 0;
  }
  final sorted = values.toList()..sort();
  final index = (sorted.length * 0.95).ceil() - 1;
  return sorted[index.clamp(0, sorted.length - 1)];
}
