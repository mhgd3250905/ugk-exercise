import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/product/exercise_type.dart';
import 'package:ugk_exercise/ui/pose_feedback/workout_pose_guide.dart';

void main() {
  testWidgets('guide layer renders nothing visible and ignores hits', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 567,
          height: 790,
          child: WorkoutPoseGuide(exerciseType: ExerciseType.pushup),
        ),
      ),
    );

    // The reserved frame exists so a future guide asset can inherit the anchor
    // alignment, but today it ships no asset: it is a transparent, hit-ignored
    // placeholder.
    final frameFinder = find.byKey(const ValueKey('workout-pose-guide-frame'));
    expect(frameFinder, findsOneWidget);
    final coloredBox = tester.widget<ColoredBox>(
      find.descendant(
        of: frameFinder,
        matching: find.byType(ColoredBox),
      ),
    );
    expect(coloredBox.color, const Color(0x00000000));
    expect(
      find.descendant(
        of: frameFinder,
        matching: find.byWidgetPredicate(
          (widget) => widget is IgnorePointer && widget.ignoring,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('portrait guide frame fills the band between the UI anchors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(567, 1390);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding.zero;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    // Mirrors how WorkoutPage anchors the frame: head anchor near the top
    // controls' bottom edge, wrist anchor ~16% above the stage bottom.
    const stageHeight = 1390.0;
    const topAnchor = 62 / stageHeight;
    const bottomAnchor = 1.0 - 0.16;

    await tester.pumpWidget(
      const MaterialApp(
        home: WorkoutPoseGuide(
          exerciseType: ExerciseType.pushup,
          topAnchorFraction: topAnchor,
          bottomAnchorFraction: bottomAnchor,
        ),
      ),
    );

    final frameFinder = find.byKey(const ValueKey('workout-pose-guide-frame'));
    final frame = tester.getSize(frameFinder);
    final frameTop = tester.getTopLeft(frameFinder).dy;

    expect(frame.width, lessThanOrEqualTo(567 * 0.94));
    expect(frame.width / frame.height, closeTo(1.15, 0.01));
    // Frame sits within the anchor band, never above the top anchor.
    expect(frameTop, greaterThanOrEqualTo(topAnchor * stageHeight - 1));
    // Frame centers on the band so future head/wrist content lands on anchors.
    const bandCenter = (topAnchor + bottomAnchor) / 2 * stageHeight;
    expect(tester.getCenter(frameFinder).dy, closeTo(bandCenter, 1.0));
    expect(tester.getCenter(frameFinder).dx, closeTo(567 / 2, 0.1));
  });

  testWidgets('wide guide frame respects the shorter stage dimension', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: WorkoutPoseGuide(exerciseType: ExerciseType.pushup),
      ),
    );

    final frameFinder = find.byKey(const ValueKey('workout-pose-guide-frame'));
    final frame = tester.getSize(frameFinder);
    expect(frame.width, lessThanOrEqualTo(500 * 0.68));
    expect(frame.height, lessThanOrEqualTo(400 * 0.88));
    expect(frame.width / frame.height, closeTo(1.15, 0.01));
    expect(tester.getCenter(frameFinder).dx, closeTo(250, 0.1));
  });
}
