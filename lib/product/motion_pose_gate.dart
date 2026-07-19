import '../pushup_domain.dart';

const double _shoulderConfidenceFloor = 0.25;
const double _shoulderAndWristConfidenceThreshold = 0.3;

/// Whether the keypoints still provide a trustworthy torso motion signal.
///
/// Missing arms are expected at close range and do not fail this check. A
/// confidently visible wrist above its shoulder is explicit evidence that a
/// hand left support, so it does fail.
bool motionPoseUsable(
  List<KeyPoint> keypoints, {
  double sourceHeight = SignalExtractor.referenceFrameHeight,
}) {
  if (keypoints.length < 17 || !sourceHeight.isFinite || sourceHeight <= 0) {
    return false;
  }
  final leftShoulderConfidence =
      keypoints[SignalExtractor.leftShoulder].confidence;
  final rightShoulderConfidence =
      keypoints[SignalExtractor.rightShoulder].confidence;
  final shoulderConfidence =
      (leftShoulderConfidence + rightShoulderConfidence) / 2;
  // Looking toward the floor can make the nose disappear at the bottom of a
  // valid pushup. Treat that as unknown rather than a contradiction while the
  // two shoulders, which anchor the motion signal, remain trustworthy.
  final torsoVisible =
      leftShoulderConfidence >= _shoulderConfidenceFloor &&
      rightShoulderConfidence >= _shoulderConfidenceFloor &&
      shoulderConfidence >= _shoulderAndWristConfidenceThreshold;
  if (!torsoVisible) {
    return false;
  }

  return SignalExtractor.wristsNotClearlyRaised(
    keypoints,
    minConf: _shoulderAndWristConfidenceThreshold,
    marginPx:
        SignalExtractor.wristSupportMarginPx *
        sourceHeight /
        SignalExtractor.referenceFrameHeight,
  );
}
