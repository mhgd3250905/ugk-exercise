import '../pushup_domain.dart';

const double _corePointConfidenceFloor = 0.25;
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
  final noseConfidence = keypoints[SignalExtractor.nose].confidence;
  final leftShoulderConfidence =
      keypoints[SignalExtractor.leftShoulder].confidence;
  final rightShoulderConfidence =
      keypoints[SignalExtractor.rightShoulder].confidence;
  final shoulderConfidence =
      (leftShoulderConfidence + rightShoulderConfidence) / 2;
  // Fast motion can briefly lower one core point just below 0.3. Keep a
  // bounded per-point floor while requiring the shoulder signal, which feeds
  // the counter, to retain its original average confidence threshold.
  final torsoVisible =
      noseConfidence >= _corePointConfidenceFloor &&
      leftShoulderConfidence >= _corePointConfidenceFloor &&
      rightShoulderConfidence >= _corePointConfidenceFloor &&
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
