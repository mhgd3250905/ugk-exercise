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

  return SignalExtractor.wristsNotClearlyRaised(
    keypoints,
    minConf: confidenceThreshold,
  );
}
