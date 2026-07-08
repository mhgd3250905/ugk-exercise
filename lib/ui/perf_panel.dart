import 'package:flutter/material.dart';

import '../perf/performance_meter.dart';

class PerfPanel extends StatelessWidget {
  const PerfPanel({super.key, required this.snapshot});

  final PerfSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Text(
      'pre ${snapshot.preprocessMs}ms | infer ${snapshot.inferMs}ms | '
      'e2e ${snapshot.e2eMs}ms | avg ${snapshot.meanE2eMs.toStringAsFixed(1)}ms | '
      'p95 ${snapshot.p95E2eMs}ms | ${snapshot.fps.toStringAsFixed(1)} fps | '
      'ui ${snapshot.uiFps.toStringAsFixed(0)} fps',
      style: style,
    );
  }
}
