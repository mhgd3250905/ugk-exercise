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

    test('accepts a practical mildly wider wrist stance', () {
      final result = gate.evaluate(
        _pose(leftWristX: 286.8, rightWristX: 433.2),
      );

      expect(result.wristSpanRatio, closeTo(1.22, 0.001));
      expect(result.elbowSpanRatio, lessThanOrEqualTo(1.35));
      expect(result.forearmDirectionDeltaDegrees, lessThanOrEqualTo(30));
      expect(result.status, NarrowPushupFormStatus.matches);
    });

    test('uses an inclusive 1.5 wrist-span boundary', () {
      // Shoulder span is 120 (300..420). A 180 wrist span lands exactly on the
      // 1.5 boundary; elbows widen to 160 (ratio 1.333, still under 1.35) so the
      // forearms stay near-vertical and only the wrist span decides the verdict.
      final exact = gate.evaluate(
        _pose(
          leftElbowX: 280,
          rightElbowX: 440,
          leftWristX: 270,
          rightWristX: 450,
        ),
      );
      final outside = gate.evaluate(
        _pose(
          leftElbowX: 280,
          rightElbowX: 440,
          leftWristX: 269.94,
          rightWristX: 450.06,
        ),
      );

      expect(exact.wristSpanRatio, closeTo(1.5, 0.000001));
      expect(exact.status, NarrowPushupFormStatus.matches);
      expect(outside.wristSpanRatio, greaterThan(1.5));
      expect(outside.elbowSpanRatio, lessThanOrEqualTo(1.35));
      expect(
        outside.forearmDirectionDeltaDegrees,
        lessThanOrEqualTo(30),
      );
      expect(outside.status, NarrowPushupFormStatus.doesNotMatch);
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
      expect(result.wristSpanRatio, greaterThan(1.25));
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

      expect(result.wristSpanRatio, lessThanOrEqualTo(1.25));
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
