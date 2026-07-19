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
    expect(pipeline.calibrateReadyDepth(readyPose), isTrue);

    for (final torsoY in [
      for (var i = 0; i < 20; i++) 200.0,
      for (var i = 0; i < 20; i++) 350.0,
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

  test('quick torso cycle survives mild core confidence dips', () {
    final pipeline = PushupPipeline();
    final readyPose = _pose(200);

    expect(pipeline.calibrateReadyDepth(readyPose), isTrue);

    for (var i = 0; i < 20; i++) {
      final keypoints = _pose(200, armsVisible: false);
      expect(motionPoseUsable(keypoints), isTrue);
      pipeline.process(keypoints);
    }
    for (var i = 0; i < 20; i++) {
      final keypoints = i.isEven
          ? _pose(350, armsVisible: false, noseConfidence: 0.27)
          : _pose(350, armsVisible: false, leftShoulderConfidence: 0.27);
      expect(motionPoseUsable(keypoints), isTrue);
      pipeline.process(keypoints);
    }
    for (var i = 0; i < 20; i++) {
      final keypoints = _pose(200, armsVisible: false);
      expect(motionPoseUsable(keypoints), isTrue);
      pipeline.process(keypoints);
    }

    expect(pipeline.count, 1);
  });

  test('quick torso cycle counts when the nose disappears at bottom', () {
    final pipeline = PushupPipeline();
    final readyPose = _pose(200);

    expect(pipeline.calibrateReadyDepth(readyPose), isTrue);

    void processIfUsable(List<KeyPoint> keypoints) {
      if (motionPoseUsable(keypoints)) {
        pipeline.process(keypoints);
      }
    }

    for (var i = 0; i < 20; i++) {
      processIfUsable(_pose(200, armsVisible: false));
    }
    for (var i = 0; i < 5; i++) {
      processIfUsable(_pose(350, armsVisible: false, noseConfidence: 0.05));
    }
    for (var i = 0; i < 20; i++) {
      processIfUsable(_pose(200, armsVisible: false));
    }

    expect(pipeline.count, 1);
  });

  test('motion pose still rejects materially lost shoulder signal', () {
    expect(
      motionPoseUsable(
        _pose(200, leftShoulderConfidence: 0.27, rightShoulderConfidence: 0.27),
      ),
      isFalse,
    );
  });

  test('motion pose applies inclusive confidence boundaries', () {
    expect(
      motionPoseUsable(
        _pose(
          200,
          noseConfidence: 0.05,
          leftShoulderConfidence: 0.25,
          rightShoulderConfidence: 0.35,
        ),
      ),
      isTrue,
    );
    expect(
      motionPoseUsable(
        _pose(200, leftShoulderConfidence: 0.249, rightShoulderConfidence: 0.9),
      ),
      isFalse,
    );
    expect(
      motionPoseUsable(
        _pose(
          200,
          leftShoulderConfidence: 0.25,
          rightShoulderConfidence: 0.349,
        ),
      ),
      isFalse,
    );
    expect(
      motionPoseUsable(_pose(200, leftRaised: true, leftWristConfidence: 0.3)),
      isFalse,
    );
  });
}

List<KeyPoint> _pose(
  double torsoY, {
  bool armsVisible = true,
  bool leftRaised = false,
  double noseConfidence = 0.9,
  double leftShoulderConfidence = 0.9,
  double rightShoulderConfidence = 0.9,
  double? leftWristConfidence,
}) {
  final points = List<KeyPoint>.generate(
    17,
    (index) => KeyPoint(index: index, x: 0, y: 0, confidence: 0.9),
  );
  points[SignalExtractor.nose] = KeyPoint(
    index: SignalExtractor.nose,
    x: 360,
    y: torsoY,
    confidence: noseConfidence,
  );
  points[SignalExtractor.leftShoulder] = KeyPoint(
    index: SignalExtractor.leftShoulder,
    x: 300,
    y: torsoY + 40,
    confidence: leftShoulderConfidence,
  );
  points[SignalExtractor.rightShoulder] = KeyPoint(
    index: SignalExtractor.rightShoulder,
    x: 420,
    y: torsoY + 40,
    confidence: rightShoulderConfidence,
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
    confidence: leftWristConfidence ?? (armsVisible ? 0.9 : 0.05),
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
