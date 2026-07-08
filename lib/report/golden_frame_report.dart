import 'dart:math' as math;

Map<String, Object> buildGoldenFrameReport({
  required String appCsv,
  required String step0Csv,
}) {
  final appRows = _readRows(appCsv);
  final step0Rows = {for (final row in _readRows(step0Csv)) row['frame']!: row};
  final coordDiffs = <double>[];
  final confDiffs = <double>[];
  final details = <Map<String, Object>>[];
  var frames = 0;

  for (final app in appRows) {
    final step0 = step0Rows[app['frame']];
    if (step0 == null) {
      continue;
    }
    frames += 1;
    for (final key in app.keys) {
      if (key == 'frame' || !step0.containsKey(key)) {
        continue;
      }
      if (key.endsWith('_conf')) {
        final diff = (double.parse(app[key]!) - double.parse(step0[key]!))
            .abs();
        confDiffs.add(diff);
      } else if (key.endsWith('_x')) {
        final keypoint = key.substring(0, key.length - 2);
        final yKey = '${keypoint}_y';
        if (!app.containsKey(yKey) || !step0.containsKey(yKey)) {
          continue;
        }
        final dx = double.parse(app[key]!) - double.parse(step0[key]!);
        final dy = double.parse(app[yKey]!) - double.parse(step0[yKey]!);
        final coordDiff = math.sqrt(dx * dx + dy * dy);
        coordDiffs.add(coordDiff);
        final confKey = '${keypoint}_conf';
        if (app.containsKey(confKey) && step0.containsKey(confKey)) {
          details.add({
            'frame': int.tryParse(app['frame']!) ?? app['frame']!,
            'keypoint': keypoint,
            'coord_diff_px': coordDiff,
            'conf_abs_diff':
                (double.parse(app[confKey]!) - double.parse(step0[confKey]!))
                    .abs(),
          });
        }
      }
    }
  }

  final coordMedian = _percentile(coordDiffs, 0.5);
  final coordP95 = _percentile(coordDiffs, 0.95);
  final confMean = confDiffs.isEmpty
      ? 0.0
      : confDiffs.reduce((a, b) => a + b) / confDiffs.length;

  return {
    'frames': frames,
    'points': confDiffs.length,
    'coord_median_px': coordMedian,
    'coord_p95_px': coordP95,
    'conf_mean_abs_diff': confMean,
    'details': details,
    'pass': coordMedian <= 5 && coordP95 <= 15 && confMean <= 0.1,
  };
}

List<Map<String, String>> _readRows(String csv) {
  final lines = csv
      .split(RegExp(r'\r?\n'))
      .where((line) => line.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) {
    return const [];
  }
  final headers = lines.first.split(',');
  return [
    for (final line in lines.skip(1))
      {for (var i = 0; i < headers.length; i++) headers[i]: line.split(',')[i]},
  ];
}

double _percentile(List<double> values, double p) {
  if (values.isEmpty) {
    return 0;
  }
  final sorted = values.toList()..sort();
  final index = math.min(
    sorted.length - 1,
    math.max(0, (sorted.length * p).ceil() - 1),
  );
  return sorted[index];
}
