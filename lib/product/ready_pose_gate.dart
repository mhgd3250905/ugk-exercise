import '../pushup_domain.dart';

class ReadyPoseGate {
  ReadyPoseGate({
    this.confidenceThreshold = 0.3,
    this.stableDuration = const Duration(milliseconds: 500),
    this.centerMarginRatio = 0.1,
    this.maxJitterPx = 30,
  });

  final double confidenceThreshold;
  final Duration stableDuration;
  final double centerMarginRatio;
  final double maxJitterPx;

  DateTime? _stableSince;
  double? _anchorX;
  double? _anchorY;

  bool update({
    required List<KeyPoint> keypoints,
    required double frameWidth,
    required double frameHeight,
    required DateTime at,
  }) {
    if (keypoints.length < 17 || frameWidth <= 0 || frameHeight <= 0) {
      reset();
      return false;
    }

    final nose = keypoints[SignalExtractor.nose];
    final leftShoulder = keypoints[SignalExtractor.leftShoulder];
    final rightShoulder = keypoints[SignalExtractor.rightShoulder];
    if (!isPoseVisible(keypoints)) {
      reset();
      return false;
    }

    final centerX = (nose.x + leftShoulder.x + rightShoulder.x) / 3;
    final centerY = (nose.y + leftShoulder.y + rightShoulder.y) / 3;
    final minX = frameWidth * centerMarginRatio;
    final maxX = frameWidth * (1 - centerMarginRatio);
    final minY = frameHeight * centerMarginRatio;
    final maxY = frameHeight * (1 - centerMarginRatio);
    if (centerX < minX || centerX > maxX || centerY < minY || centerY > maxY) {
      reset();
      return false;
    }

    final anchorX = _anchorX;
    final anchorY = _anchorY;
    if (anchorX == null || anchorY == null || _stableSince == null) {
      _anchorX = centerX;
      _anchorY = centerY;
      _stableSince = at;
      return false;
    }

    final dx = centerX - anchorX;
    final dy = centerY - anchorY;
    if (dx * dx + dy * dy > maxJitterPx * maxJitterPx) {
      _anchorX = centerX;
      _anchorY = centerY;
      _stableSince = at;
      return false;
    }

    return at.difference(_stableSince!) >= stableDuration;
  }

  bool isPoseVisible(List<KeyPoint> keypoints) {
    if (keypoints.length < 17) {
      return false;
    }
    for (final index in [
      SignalExtractor.nose,
      SignalExtractor.leftShoulder,
      SignalExtractor.rightShoulder,
      SignalExtractor.leftWrist,
      SignalExtractor.rightWrist,
      SignalExtractor.leftHip,
      SignalExtractor.rightHip,
    ]) {
      if (keypoints[index].confidence < confidenceThreshold) {
        return false;
      }
    }
    return SignalExtractor.wristsBelowShoulders(keypoints);
  }

  void reset() {
    _stableSince = null;
    _anchorX = null;
    _anchorY = null;
  }
}
