import 'dart:math' as math;

import '../pushup_domain.dart';

enum NarrowPushupFormStatus { matches, doesNotMatch, unknown }

class NarrowPushupFormResult {
  const NarrowPushupFormResult({
    required this.status,
    this.wristSpanRatio,
    this.elbowSpanRatio,
    this.forearmDirectionDeltaDegrees,
  });

  const NarrowPushupFormResult.unknown()
    : status = NarrowPushupFormStatus.unknown,
      wristSpanRatio = null,
      elbowSpanRatio = null,
      forearmDirectionDeltaDegrees = null;

  final NarrowPushupFormStatus status;
  final double? wristSpanRatio;
  final double? elbowSpanRatio;
  final double? forearmDirectionDeltaDegrees;
}

/// Evaluates whether a reliably visible top pose rules out an obviously wide
/// pushup stance.
///
/// This is deliberately a conservative 2D eligibility gate, not a full pose
/// classifier. Ratios are normalized by shoulder width so camera translation
/// and subject scale do not change the verdict.
class NarrowPushupFormGate {
  const NarrowPushupFormGate({
    this.confidenceThreshold = 0.3,
    this.maxWristSpanRatio = 1.25,
    this.maxElbowSpanRatio = 1.35,
    this.maxForearmDirectionDeltaDegrees = 30,
    this.minForearmVerticalRatio = 0.25,
    this.minShoulderSpanPx = 1,
  });

  final double confidenceThreshold;
  final double maxWristSpanRatio;
  final double maxElbowSpanRatio;
  final double maxForearmDirectionDeltaDegrees;
  final double minForearmVerticalRatio;
  final double minShoulderSpanPx;

  NarrowPushupFormResult evaluate(List<KeyPoint> keypoints) {
    if (keypoints.length < 17) {
      return const NarrowPushupFormResult.unknown();
    }
    final leftShoulder = keypoints[SignalExtractor.leftShoulder];
    final rightShoulder = keypoints[SignalExtractor.rightShoulder];
    final leftElbow = keypoints[SignalExtractor.leftElbow];
    final rightElbow = keypoints[SignalExtractor.rightElbow];
    final leftWrist = keypoints[SignalExtractor.leftWrist];
    final rightWrist = keypoints[SignalExtractor.rightWrist];
    final requiredPoints = [
      leftShoulder,
      rightShoulder,
      leftElbow,
      rightElbow,
      leftWrist,
      rightWrist,
    ];
    if (requiredPoints.any(
      (point) =>
          !point.confidence.isFinite ||
          point.confidence < confidenceThreshold ||
          !point.x.isFinite ||
          !point.y.isFinite,
    )) {
      return const NarrowPushupFormResult.unknown();
    }

    final shoulderSpan = (leftShoulder.x - rightShoulder.x).abs();
    final leftForearmDy = leftWrist.y - leftElbow.y;
    final rightForearmDy = rightWrist.y - rightElbow.y;
    if (!shoulderSpan.isFinite ||
        shoulderSpan < minShoulderSpanPx ||
        leftForearmDy < minForearmVerticalRatio * shoulderSpan ||
        rightForearmDy < minForearmVerticalRatio * shoulderSpan) {
      return const NarrowPushupFormResult.unknown();
    }

    final wristSpanRatio = (leftWrist.x - rightWrist.x).abs() / shoulderSpan;
    final elbowSpanRatio = (leftElbow.x - rightElbow.x).abs() / shoulderSpan;
    final leftDirection = math.atan2(leftWrist.x - leftElbow.x, leftForearmDy);
    final rightDirection = math.atan2(
      rightWrist.x - rightElbow.x,
      rightForearmDy,
    );
    final directionDelta =
        (leftDirection - rightDirection).abs() * 180 / math.pi;
    if (!wristSpanRatio.isFinite ||
        !elbowSpanRatio.isFinite ||
        !directionDelta.isFinite) {
      return const NarrowPushupFormResult.unknown();
    }
    final matches =
        wristSpanRatio <= maxWristSpanRatio &&
        elbowSpanRatio <= maxElbowSpanRatio &&
        directionDelta <= maxForearmDirectionDeltaDegrees;
    return NarrowPushupFormResult(
      status: matches
          ? NarrowPushupFormStatus.matches
          : NarrowPushupFormStatus.doesNotMatch,
      wristSpanRatio: wristSpanRatio,
      elbowSpanRatio: elbowSpanRatio,
      forearmDirectionDeltaDegrees: directionDelta,
    );
  }
}
