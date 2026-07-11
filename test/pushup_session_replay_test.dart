import 'package:test/test.dart';
import 'package:ugk_exercise/product/motion_pose_gate.dart';
import 'package:ugk_exercise/product/pushup_pipeline.dart';
import 'package:ugk_exercise/product/ready_pose_gate.dart';
import 'package:ugk_exercise/product/wrist_anchor.dart';
import 'package:ugk_exercise/pushup_domain.dart';

void main() {
  test('strict ready then arm dropout torso cycle counts one rep', () {
    final readyGate = ReadyPoseGate();
    final wristAnchor = WristAnchor();
    final pipeline = PushupPipeline();
    final start = DateTime(2026, 7, 11, 10);
    final readyPose = _pose(200);

    expect(
      readyGate.update(
        keypoints: readyPose,
        frameWidth: 720,
        frameHeight: 1280,
        at: start,
      ),
      isFalse,
    );
    expect(
      readyGate.update(
        keypoints: readyPose,
        frameWidth: 720,
        frameHeight: 1280,
        at: start.add(const Duration(milliseconds: 500)),
      ),
      isTrue,
    );
    wristAnchor.calibrate(readyPose);
    expect(wristAnchor.isCalibrated, isTrue);

    for (final torsoY in [
      for (var i = 0; i < 20; i++) 200.0,
      for (var i = 0; i < 20; i++) 300.0,
      for (var i = 0; i < 20; i++) 200.0,
    ]) {
      final keypoints = _pose(torsoY, armsVisible: false);
      expect(motionPoseUsable(keypoints), isTrue);
      pipeline.process(keypoints, handsStable: wristAnchor.isStable(keypoints));
    }

    expect(pipeline.count, 1);
  });

  test('motion pose rejects a confidently visible raised wrist', () {
    expect(motionPoseUsable(_pose(200, leftRaised: true)), isFalse);
  });
}

List<KeyPoint> _pose(
  double torsoY, {
  bool armsVisible = true,
  bool leftRaised = false,
}) {
  final points = List<KeyPoint>.generate(
    17,
    (index) => KeyPoint(index: index, x: 0, y: 0, confidence: 0.9),
  );
  points[SignalExtractor.nose] = KeyPoint(
    index: SignalExtractor.nose,
    x: 360,
    y: torsoY,
    confidence: 0.9,
  );
  points[SignalExtractor.leftShoulder] = KeyPoint(
    index: SignalExtractor.leftShoulder,
    x: 300,
    y: torsoY + 40,
    confidence: 0.9,
  );
  points[SignalExtractor.rightShoulder] = KeyPoint(
    index: SignalExtractor.rightShoulder,
    x: 420,
    y: torsoY + 40,
    confidence: 0.9,
  );
  points[SignalExtractor.leftElbow] = KeyPoint(
    index: SignalExtractor.leftElbow,
    x: 260,
    y: torsoY + 160,
    confidence: armsVisible ? 0.9 : 0.05,
  );
  points[SignalExtractor.rightElbow] = KeyPoint(
    index: SignalExtractor.rightElbow,
    x: 460,
    y: torsoY + 160,
    confidence: armsVisible ? 0.9 : 0.05,
  );
  points[SignalExtractor.leftWrist] = KeyPoint(
    index: SignalExtractor.leftWrist,
    x: 300,
    y: leftRaised ? torsoY - 80 : torsoY + 280,
    confidence: armsVisible ? 0.9 : 0.05,
  );
  points[SignalExtractor.rightWrist] = KeyPoint(
    index: SignalExtractor.rightWrist,
    x: 420,
    y: torsoY + 280,
    confidence: armsVisible ? 0.9 : 0.05,
  );
  points[SignalExtractor.leftHip] = KeyPoint(
    index: SignalExtractor.leftHip,
    x: 320,
    y: torsoY + 120,
    confidence: 0.9,
  );
  points[SignalExtractor.rightHip] = KeyPoint(
    index: SignalExtractor.rightHip,
    x: 400,
    y: torsoY + 120,
    confidence: 0.9,
  );
  return points;
}
