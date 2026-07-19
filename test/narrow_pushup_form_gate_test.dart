import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/product/exercise_type.dart';
import 'package:ugk_exercise/product/narrow_pushup_form_gate.dart';
import 'package:ugk_exercise/pushup_domain.dart';

void main() {
  test('exercise types expose stable persistence values', () {
    expect(ExerciseType.pushup.storageValue, 'pushup');
    expect(ExerciseType.narrowPushup.storageValue, 'narrow_pushup');
  });

  group('NarrowPushupFormGate', () {
    const gate = NarrowPushupFormGate();

    test('accepts close approximately parallel forearms', () {
      final result = gate.evaluate(_pose());

      expect(result.status, NarrowPushupFormStatus.matches);
      expect(result.wristSpanRatio, closeTo(0.75, 0.001));
      expect(result.elbowSpanRatio, closeTo(100 / 120, 0.001));
      expect(result.forearmDirectionDeltaDegrees, lessThan(10));
    });

    test('rejects an obviously wide trapezoid', () {
      final result = gate.evaluate(
        _pose(
          leftElbowX: 260,
          rightElbowX: 460,
          leftWristX: 240,
          rightWristX: 480,
        ),
      );

      expect(result.status, NarrowPushupFormStatus.doesNotMatch);
      expect(result.wristSpanRatio, greaterThan(1.15));
      expect(result.elbowSpanRatio, greaterThan(1.35));
    });

    test('rejects divergent forearms even when spans are not wide', () {
      final result = gate.evaluate(
        _pose(
          leftElbowX: 340,
          rightElbowX: 380,
          leftWristX: 300,
          rightWristX: 420,
        ),
      );

      expect(result.wristSpanRatio, lessThanOrEqualTo(1.15));
      expect(result.elbowSpanRatio, lessThanOrEqualTo(1.35));
      expect(result.forearmDirectionDeltaDegrees, greaterThan(30));
      expect(result.status, NarrowPushupFormStatus.doesNotMatch);
    });

    test('keeps mildly asymmetric arms inside the tolerance', () {
      final result = gate.evaluate(
        _pose(
          leftElbowX: 300,
          rightElbowX: 425,
          leftWristX: 310,
          rightWristX: 430,
        ),
      );

      expect(result.status, NarrowPushupFormStatus.matches);
    });

    test('returns unknown when any required arm point is low confidence', () {
      final points = _pose();
      points[SignalExtractor.leftWrist] = _point(
        SignalExtractor.leftWrist,
        x: 315,
        y: 480,
        confidence: 0.299,
      );

      expect(gate.evaluate(points).status, NarrowPushupFormStatus.unknown);
    });

    test('returns unknown for non-finite confidence', () {
      for (final confidence in [double.nan, double.infinity]) {
        final points = _pose();
        points[SignalExtractor.leftWrist] = _point(
          SignalExtractor.leftWrist,
          x: 315,
          y: 480,
          confidence: confidence,
        );

        expect(gate.evaluate(points).status, NarrowPushupFormStatus.unknown);
      }
    });

    test('returns unknown for degenerate or non-downward geometry', () {
      expect(
        gate.evaluate(_pose(leftShoulderX: 360, rightShoulderX: 360)).status,
        NarrowPushupFormStatus.unknown,
      );
      expect(
        gate.evaluate(_pose(wristY: 350)).status,
        NarrowPushupFormStatus.unknown,
      );
      expect(
        gate
            .evaluate(_pose(leftShoulderX: 360, rightShoulderX: 360.000001))
            .status,
        NarrowPushupFormStatus.unknown,
      );
    });

    test('wide rejection survives translation scale and mirroring', () {
      final wide = _pose(
        leftElbowX: 260,
        rightElbowX: 460,
        leftWristX: 240,
        rightWristX: 480,
      );

      for (final transformed in [
        _transform(wide, scale: 0.55, dx: 180, dy: -40),
        _transform(wide, scale: 1.8, dx: -260, dy: 90),
        _transform(wide, scaleX: -1, dx: 720),
      ]) {
        expect(
          gate.evaluate(transformed).status,
          NarrowPushupFormStatus.doesNotMatch,
        );
      }
    });
  });
}

List<KeyPoint> _pose({
  double leftShoulderX = 300,
  double rightShoulderX = 420,
  double leftElbowX = 310,
  double rightElbowX = 410,
  double leftWristX = 315,
  double rightWristX = 405,
  double wristY = 480,
}) {
  final points = List<KeyPoint>.generate(
    17,
    (index) => _point(index, x: 360, y: 300, confidence: 0.05),
  );
  points[SignalExtractor.leftShoulder] = _point(
    SignalExtractor.leftShoulder,
    x: leftShoulderX,
    y: 240,
  );
  points[SignalExtractor.rightShoulder] = _point(
    SignalExtractor.rightShoulder,
    x: rightShoulderX,
    y: 240,
  );
  points[SignalExtractor.leftElbow] = _point(
    SignalExtractor.leftElbow,
    x: leftElbowX,
    y: 360,
  );
  points[SignalExtractor.rightElbow] = _point(
    SignalExtractor.rightElbow,
    x: rightElbowX,
    y: 360,
  );
  points[SignalExtractor.leftWrist] = _point(
    SignalExtractor.leftWrist,
    x: leftWristX,
    y: wristY,
  );
  points[SignalExtractor.rightWrist] = _point(
    SignalExtractor.rightWrist,
    x: rightWristX,
    y: wristY,
  );
  return points;
}

KeyPoint _point(
  int index, {
  required double x,
  required double y,
  double confidence = 0.9,
}) {
  return KeyPoint(index: index, x: x, y: y, confidence: confidence);
}

List<KeyPoint> _transform(
  List<KeyPoint> points, {
  double scale = 1,
  double? scaleX,
  double dx = 0,
  double dy = 0,
}) {
  return [
    for (final point in points)
      KeyPoint(
        index: point.index,
        x: point.x * (scaleX ?? scale) + dx,
        y: point.y * scale + dy,
        confidence: point.confidence,
      ),
  ];
}
