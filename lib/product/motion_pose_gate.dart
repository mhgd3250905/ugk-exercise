import '../pushup_domain.dart';

/// Whether the keypoints still provide a trustworthy torso motion signal.
///
/// Missing arms are expected at close range and do not fail this check. A
/// confidently visible wrist above its shoulder is explicit evidence that a
/// hand left support, so it does fail.
bool motionPoseUsable(
  List<KeyPoint> keypoints, {
  double confidenceThreshold = 0.3,
}) {
  if (keypoints.length < 17) {
    return false;
  }
  final torsoVisible =
      keypoints[SignalExtractor.nose].confidence >= confidenceThreshold &&
      keypoints[SignalExtractor.leftShoulder].confidence >=
          confidenceThreshold &&
      keypoints[SignalExtractor.rightShoulder].confidence >=
          confidenceThreshold;
  if (!torsoVisible) {
    return false;
  }

  final lw = keypoints[SignalExtractor.leftWrist];
  final ls = keypoints[SignalExtractor.leftShoulder];
  final rw = keypoints[SignalExtractor.rightWrist];
  final rs = keypoints[SignalExtractor.rightShoulder];
  final leftRaised =
      lw.confidence >= confidenceThreshold &&
      lw.y < ls.y - SignalExtractor.wristSupportMarginPx;
  final rightRaised =
      rw.confidence >= confidenceThreshold &&
      rw.y < rs.y - SignalExtractor.wristSupportMarginPx;
  return !leftRaised && !rightRaised;
}
