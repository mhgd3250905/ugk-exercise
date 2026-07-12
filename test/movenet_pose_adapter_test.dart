import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/pushup_domain.dart';
import 'package:ugk_exercise/ui/pose_feedback/movenet_pose_adapter.dart';

void main() {
  final at = DateTime.utc(2026, 7, 12);

  test('maps and normalizes MoveNet head and shoulder landmarks', () {
    final observation = moveNetHeadShoulderObservation(
      keypoints: _pose(),
      sourceSize: const Size(200, 400),
      at: at,
    );

    expect(observation.head?.x, 0.5);
    expect(observation.head?.y, 0.2);
    expect(observation.headConfidence, 0.9);
    expect(observation.leftShoulder?.x, 0.3);
    expect(observation.leftShoulder?.y, 0.5);
    expect(observation.rightShoulder?.x, 0.7);
    expect(observation.rightShoulder?.y, 0.5);
  });

  test(
    'falls back to the visible face cluster when the nose is unreliable',
    () {
      final keypoints = _pose();
      keypoints[0] = _point(0, 100, 80, 0.1);
      keypoints[1] = _point(1, 80, 80, 0.8);
      keypoints[2] = _point(2, 120, 80, 0.8);

      final observation = moveNetHeadShoulderObservation(
        keypoints: keypoints,
        sourceSize: const Size(200, 400),
        at: at,
      );

      expect(observation.head?.x, 0.5);
      expect(observation.head?.y, 0.2);
      expect(observation.headConfidence, 0.8);
    },
  );

  test('returns a missing observation for invalid input', () {
    final invalidSize = moveNetHeadShoulderObservation(
      keypoints: _pose(),
      sourceSize: Size.zero,
      at: at,
    );
    final missingPoints = moveNetHeadShoulderObservation(
      keypoints: const [],
      sourceSize: const Size(200, 400),
      at: at,
    );

    expect(invalidSize.head, isNull);
    expect(invalidSize.leftShoulder, isNull);
    expect(missingPoints.head, isNull);
    expect(missingPoints.rightShoulder, isNull);
  });
}

List<KeyPoint> _pose() {
  final keypoints = List<KeyPoint>.generate(
    17,
    (index) => _point(index, 100, 200, 0.1),
  );
  keypoints[0] = _point(0, 100, 80, 0.9);
  keypoints[5] = _point(5, 60, 200, 0.9);
  keypoints[6] = _point(6, 140, 200, 0.9);
  return keypoints;
}

KeyPoint _point(int index, double x, double y, double confidence) {
  return KeyPoint(index: index, x: x, y: y, confidence: confidence);
}
