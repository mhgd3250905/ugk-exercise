import 'dart:ui';

import '../../pushup_domain.dart';
import 'pose_silhouette_tracker.dart';

const _faceConfidenceThreshold = 0.3;

HeadShoulderObservation moveNetHeadShoulderObservation({
  required List<KeyPoint> keypoints,
  required Size sourceSize,
  required DateTime at,
}) {
  if (keypoints.length < 7 ||
      !sourceSize.width.isFinite ||
      !sourceSize.height.isFinite ||
      sourceSize.width <= 0 ||
      sourceSize.height <= 0) {
    return HeadShoulderObservation.missing(at);
  }

  final head = _headAnchor(keypoints);
  final leftShoulder = keypoints[5];
  final rightShoulder = keypoints[6];
  return HeadShoulderObservation(
    at: at,
    head: head == null ? null : _normalize(head.point, sourceSize),
    headConfidence: head?.confidence ?? 0,
    leftShoulder: _normalize(leftShoulder, sourceSize),
    leftShoulderConfidence: leftShoulder.confidence,
    rightShoulder: _normalize(rightShoulder, sourceSize),
    rightShoulderConfidence: rightShoulder.confidence,
  );
}

({KeyPoint point, double confidence})? _headAnchor(List<KeyPoint> keypoints) {
  final nose = keypoints[0];
  if (nose.confidence >= _faceConfidenceThreshold) {
    return (point: nose, confidence: nose.confidence);
  }

  var weight = 0.0;
  var x = 0.0;
  var y = 0.0;
  var confidence = 0.0;
  for (final point in keypoints.take(5)) {
    if (point.confidence < _faceConfidenceThreshold) {
      continue;
    }
    weight += point.confidence;
    x += point.x * point.confidence;
    y += point.y * point.confidence;
    if (point.confidence > confidence) {
      confidence = point.confidence;
    }
  }
  if (weight == 0) {
    return null;
  }
  return (
    point: KeyPoint(
      index: 0,
      x: x / weight,
      y: y / weight,
      confidence: confidence,
    ),
    confidence: confidence,
  );
}

NormalizedPosePoint _normalize(KeyPoint point, Size sourceSize) {
  return NormalizedPosePoint(
    point.x / sourceSize.width,
    point.y / sourceSize.height,
  );
}
