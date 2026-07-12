import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/ui/pose_feedback/pose_silhouette_overlay.dart';
import 'package:ugk_exercise/ui/pose_feedback/pose_silhouette_tracker.dart';

void main() {
  final origin = DateTime.utc(2026, 7, 12);

  testWidgets('paints geometry only after the observation is stable', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_valid(origin)));
    expect(_painter(tester).geometry, isNull);

    await tester.pumpWidget(
      _host(_valid(origin.add(const Duration(milliseconds: 150)))),
    );

    expect(_painter(tester).geometry, isNotNull);
  });

  testWidgets('holds a short dropout and hides a sustained dropout', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_valid(origin)));
    await tester.pumpWidget(
      _host(_valid(origin.add(const Duration(milliseconds: 150)))),
    );
    final visible = _painter(tester).geometry;

    await tester.pumpWidget(
      _host(
        HeadShoulderObservation.missing(
          origin.add(const Duration(milliseconds: 350)),
        ),
      ),
    );
    expect(_painter(tester).geometry, same(visible));

    await tester.pumpWidget(
      _host(
        HeadShoulderObservation.missing(
          origin.add(const Duration(milliseconds: 451)),
        ),
      ),
    );
    expect(_painter(tester).geometry, isNull);
  });

  testWidgets('a new overlay starts with a reset tracker', (tester) async {
    await tester.pumpWidget(_host(_valid(origin)));
    await tester.pumpWidget(
      _host(_valid(origin.add(const Duration(milliseconds: 150)))),
    );
    expect(_painter(tester).geometry, isNotNull);

    await tester.pumpWidget(
      _host(
        _valid(origin.add(const Duration(milliseconds: 200))),
        overlayKey: const ValueKey('new-session'),
      ),
    );

    expect(_painter(tester).geometry, isNull);
  });
}

Widget _host(HeadShoulderObservation observation, {Key? overlayKey}) {
  return MaterialApp(
    home: SizedBox(
      width: 200,
      height: 400,
      child: PoseSilhouetteOverlay(key: overlayKey, observation: observation),
    ),
  );
}

PoseSilhouettePainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byKey(const ValueKey('pose-silhouette-canvas')),
  );
  return paint.painter! as PoseSilhouettePainter;
}

HeadShoulderObservation _valid(DateTime at) {
  return HeadShoulderObservation(
    at: at,
    head: const NormalizedPosePoint(0.5, 0.25),
    headConfidence: 0.9,
    leftShoulder: const NormalizedPosePoint(0.3, 0.5),
    leftShoulderConfidence: 0.9,
    rightShoulder: const NormalizedPosePoint(0.7, 0.5),
    rightShoulderConfidence: 0.9,
  );
}
