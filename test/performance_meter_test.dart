import 'package:test/test.dart';
import 'package:ugk_exercise/perf/performance_meter.dart';

void main() {
  test('tracks current mean p95 and fps over the rolling window', () {
    final meter = PerformanceMeter(window: 2);

    meter.recordPreprocess(10);
    meter.recordInfer(40);
    meter.recordPreprocess(30);
    meter.recordInfer(70);
    meter.recordPreprocess(20);
    meter.recordInfer(30);

    final snapshot = meter.snapshot;

    expect(snapshot.preprocessMs, 20);
    expect(snapshot.inferMs, 30);
    expect(snapshot.e2eMs, 50);
    expect(snapshot.meanE2eMs, 75);
    expect(snapshot.p95E2eMs, 100);
    expect(snapshot.fps, closeTo(1000 / 75, 1e-9));
  });

  test('tracks ui fps from recent rebuild timestamps', () {
    final meter = PerformanceMeter();

    meter.recordUiFrame(1000);
    meter.recordUiFrame(1250);
    meter.recordUiFrame(1500);
    meter.recordUiFrame(2000);

    expect(meter.snapshot.uiFps, 4);

    meter.recordUiFrame(2601);

    expect(meter.snapshot.uiFps, 2);
  });
}
