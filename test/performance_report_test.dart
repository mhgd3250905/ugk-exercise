import 'package:test/test.dart';
import 'package:ugk_exercise/report/performance_report.dart';
import 'package:ugk_exercise/pushup_domain.dart';

void main() {
  test('builds an offline performance report from measured samples', () {
    final report = buildPerformanceReport(
      mode: 'offline_replay',
      delegate: 'cpu',
      finalCount: 5,
      totalElapsedMs: 200,
      samples: [
        PerformanceSample(
          preprocessMs: 10,
          inferMs: 30,
          keypoints: _keypoints(confidence: 0.5),
        ),
        PerformanceSample(
          preprocessMs: 20,
          inferMs: 50,
          keypoints: _keypoints(confidence: 0.7),
        ),
      ],
    );

    expect(report['mode'], 'offline_replay');
    expect(report['delegate'], 'cpu');
    expect(report['final_count'], 5);
    expect(report['frames'], 2);
    expect(report['total_ms'], 200);
    expect(report['mean_preprocess_ms'], 15);
    expect(report['mean_infer_ms'], 40);
    expect(report['mean_e2e_ms'], 55);
    expect(report['p95_e2e_ms'], 70);
    expect(report['fps'], 10);
    expect(report['memory_peak_mb'], 0);
    expect(report['pass'], isTrue);

    final confidences =
        report['keypoint_mean_confidence'] as Map<String, Object>;
    expect(confidences['nose'], closeTo(0.6, 1e-9));
    expect(confidences['left_ankle'], closeTo(0.6, 1e-9));
  });

  test('marks reports below the hard FPS gate as failing', () {
    final report = buildPerformanceReport(
      mode: 'offline_replay',
      delegate: 'cpu',
      finalCount: 5,
      totalElapsedMs: 500,
      samples: [
        PerformanceSample(
          preprocessMs: 100,
          inferMs: 100,
          keypoints: _keypoints(confidence: 0.8),
        ),
      ],
    );

    expect(report['fps'], 2);
    expect(report['pass'], isFalse);
  });

  test('marks reports above the memory hard gate as failing', () {
    final report = buildPerformanceReport(
      mode: 'live_camera',
      delegate: 'cpu',
      finalCount: 0,
      totalElapsedMs: 100,
      memoryPeakMb: 601,
      samples: [
        PerformanceSample(
          preprocessMs: 10,
          inferMs: 10,
          keypoints: _keypoints(confidence: 0.8),
        ),
      ],
    );

    expect(report['memory_peak_mb'], 601);
    expect(report['pass'], isFalse);
  });

  test('builds a delegate fps comparison table', () {
    final comparison = buildDelegateComparison([
      _report(delegate: 'cpu', fps: 10),
      _report(delegate: 'nnapi', fps: 12),
      _report(delegate: 'gpu', fps: 14),
    ]);

    expect(comparison['pass'], isTrue);
    expect(comparison['fps_by_delegate'], {
      'cpu': 10.0,
      'nnapi': 12.0,
      'gpu': 14.0,
    });
  });

  test('fails delegate comparison when a required delegate is missing', () {
    final comparison = buildDelegateComparison([
      _report(delegate: 'cpu', fps: 10),
      _report(delegate: 'nnapi', fps: 12),
    ]);

    expect(comparison['pass'], isFalse);
  });
}

Map<String, Object> _report({required String delegate, required double fps}) {
  return {
    'delegate': delegate,
    'fps': fps,
    'mean_e2e_ms': 1000 / fps,
    'frames': 30,
    'pass': fps >= 10,
  };
}

List<KeyPoint> _keypoints({required double confidence}) {
  return [
    for (var i = 0; i < 17; i++)
      KeyPoint(
        index: i,
        x: i.toDouble(),
        y: i.toDouble(),
        confidence: confidence,
      ),
  ];
}
