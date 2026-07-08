import '../pushup_domain.dart';

const keypointNames = [
  'nose',
  'left_eye',
  'right_eye',
  'left_ear',
  'right_ear',
  'left_shoulder',
  'right_shoulder',
  'left_elbow',
  'right_elbow',
  'left_wrist',
  'right_wrist',
  'left_hip',
  'right_hip',
  'left_knee',
  'right_knee',
  'left_ankle',
  'right_ankle',
];

String keypointCsvHeader() {
  return [
    'frame',
    for (final name in keypointNames) ...[
      '${name}_x',
      '${name}_y',
      '${name}_conf',
    ],
  ].join(',');
}

String keypointCsvRow({required int frame, required List<KeyPoint> keypoints}) {
  if (keypoints.length != keypointNames.length) {
    throw ArgumentError.value(
      keypoints.length,
      'keypoints.length',
      'expected 17',
    );
  }
  return [
    '$frame',
    for (final point in keypoints) ...[
      point.x.toStringAsFixed(3),
      point.y.toStringAsFixed(3),
      point.confidence.toStringAsFixed(3),
    ],
  ].join(',');
}
