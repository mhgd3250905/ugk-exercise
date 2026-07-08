import '../inference/keypoint_log.dart';
import '../pushup_domain.dart';

class PerformanceSample {
  const PerformanceSample({
    required this.preprocessMs,
    required this.inferMs,
    required this.keypoints,
  });

  final int preprocessMs;
  final int inferMs;
  final List<KeyPoint> keypoints;

  int get e2eMs => preprocessMs + inferMs;
}

Map<String, Object> buildPerformanceReport({
  required String mode,
  required String delegate,
  required int finalCount,
  required int totalElapsedMs,
  required List<PerformanceSample> samples,
  double memoryPeakMb = 0,
}) {
  final frames = samples.length;
  final meanPreprocess = _mean(samples.map((sample) => sample.preprocessMs));
  final meanInfer = _mean(samples.map((sample) => sample.inferMs));
  final e2eValues = samples.map((sample) => sample.e2eMs).toList();
  final meanE2e = _mean(e2eValues);
  final fps = totalElapsedMs <= 0 ? 0.0 : frames * 1000 / totalElapsedMs;

  return {
    'mode': mode,
    'delegate': delegate,
    'final_count': finalCount,
    'frames': frames,
    'total_ms': totalElapsedMs,
    'mean_preprocess_ms': meanPreprocess,
    'mean_infer_ms': meanInfer,
    'mean_e2e_ms': meanE2e,
    'p95_e2e_ms': _p95(e2eValues),
    'fps': fps,
    'memory_peak_mb': memoryPeakMb,
    'keypoint_mean_confidence': _meanKeypointConfidence(samples),
    'pass': fps >= 10 && meanE2e < 250 && memoryPeakMb <= 600,
  };
}

Map<String, Object> buildDelegateComparison(
  Iterable<Map<String, Object>> reports,
) {
  final fpsByDelegate = <String, double>{};
  final requiredDelegates = {'cpu', 'nnapi', 'gpu'};
  var allPass = true;

  for (final report in reports) {
    final delegate = report['delegate'] as String;
    final fps = (report['fps'] as num).toDouble();
    fpsByDelegate[delegate] = fps;
    allPass = allPass && report['pass'] == true;
  }

  return {
    'fps_by_delegate': fpsByDelegate,
    'pass':
        allPass &&
        requiredDelegates.every(
          (delegate) => fpsByDelegate.containsKey(delegate),
        ),
  };
}

double _mean(Iterable<int> values) {
  var total = 0;
  var count = 0;
  for (final value in values) {
    total += value;
    count += 1;
  }
  return count == 0 ? 0 : total / count;
}

int _p95(List<int> values) {
  if (values.isEmpty) {
    return 0;
  }
  final sorted = values.toList()..sort();
  final index = (sorted.length * 0.95).ceil() - 1;
  return sorted[index.clamp(0, sorted.length - 1)];
}

Map<String, Object> _meanKeypointConfidence(List<PerformanceSample> samples) {
  final sums = List<double>.filled(keypointNames.length, 0);
  final counts = List<int>.filled(keypointNames.length, 0);
  for (final sample in samples) {
    for (
      var i = 0;
      i < sample.keypoints.length && i < keypointNames.length;
      i++
    ) {
      sums[i] += sample.keypoints[i].confidence;
      counts[i] += 1;
    }
  }

  return {
    for (var i = 0; i < keypointNames.length; i++)
      keypointNames[i]: counts[i] == 0 ? 0.0 : sums[i] / counts[i],
  };
}
