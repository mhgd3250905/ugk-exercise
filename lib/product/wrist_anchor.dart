import '../pushup_domain.dart';

/// Calibrated stability gate for the two wrist support points.
///
/// First-principles role: in a pushup the wrists are the anchor — they stay put
/// while the head+shoulders press down and back up. So a rep is only trustworthy
/// while both wrists hold near where they were when the user entered the ready
/// state. The two wrists are *independent* support points, so they are gated
/// with an AND: either one drifting off its baseline breaks support, and the
/// two are never averaged (averaging them is what let a single raised hand fake
/// a press in the old pressDepthY signal).
///
/// This also rejects a global camera translation: if the phone moves, both
/// wrists drift together and both leave their baselines.
class WristAnchor {
  WristAnchor({this.maxDriftPx = 50, this.minConf = 0.3});

  /// Max vertical drift (px) allowed from the calibrated baseline before a
  /// wrist counts as having left its support position. step0 replay shows a
  /// normal support jitters the wrist by only ~±15px, so 50px keeps a 3x
  /// margin while a raised hand (200px+) trips immediately.
  final double maxDriftPx;
  final double minConf;

  double? _leftBaseline;
  double? _rightBaseline;

  /// Snapshot both wrist y positions as the support baseline. Called once when
  /// the user enters the ready state.
  void calibrate(
    List<KeyPoint> keypoints, {
    double sourceHeight = SignalExtractor.referenceFrameHeight,
  }) {
    if (keypoints.length <= SignalExtractor.rightWrist ||
        !sourceHeight.isFinite ||
        sourceHeight <= 0) {
      return;
    }
    final scale = SignalExtractor.referenceFrameHeight / sourceHeight;
    final left = keypoints[SignalExtractor.leftWrist];
    final right = keypoints[SignalExtractor.rightWrist];
    if (left.confidence >= minConf) {
      _leftBaseline = left.y * scale;
    }
    if (right.confidence >= minConf) {
      _rightBaseline = right.y * scale;
    }
  }

  /// Whether the support is trustworthy this frame.
  ///
  /// Principle: a wrist the model can see (confidence >= [minConf]) must hold
  /// near its baseline; a wrist the model *cannot* see is exempt — if it's
  /// invisible we cannot claim it left support, and on a real phone a support
  /// wrist at floor level is often low-confidence, so requiring both would
  /// freeze counting on every other frame. But if *both* are invisible the
  /// support is unknowable, so we reject.
  ///
  /// A raised hand is high-confidence (the model sees it clearly at face level)
  /// and drifts off baseline, so it still breaks stability under this rule.
  bool isStable(
    List<KeyPoint> keypoints, {
    double sourceHeight = SignalExtractor.referenceFrameHeight,
  }) {
    final left = _leftBaseline;
    final right = _rightBaseline;
    if (left == null || right == null) {
      return false;
    }
    if (keypoints.length <= SignalExtractor.rightWrist ||
        !sourceHeight.isFinite ||
        sourceHeight <= 0) {
      return false;
    }
    final scale = SignalExtractor.referenceFrameHeight / sourceHeight;
    final lw = keypoints[SignalExtractor.leftWrist];
    final rw = keypoints[SignalExtractor.rightWrist];
    final leftVisible = lw.confidence >= minConf;
    final rightVisible = rw.confidence >= minConf;
    if (!leftVisible && !rightVisible) {
      return false;
    }
    if (leftVisible && (lw.y * scale - left).abs() > maxDriftPx) {
      return false;
    }
    if (rightVisible && (rw.y * scale - right).abs() > maxDriftPx) {
      return false;
    }
    return true;
  }

  bool get isCalibrated => _leftBaseline != null && _rightBaseline != null;

  void reset() {
    _leftBaseline = null;
    _rightBaseline = null;
  }
}
