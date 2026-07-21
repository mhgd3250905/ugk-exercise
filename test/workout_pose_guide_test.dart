import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/product/exercise_type.dart';
import 'package:ugk_exercise/ui/pose_feedback/workout_pose_guide.dart';

void main() {
  testWidgets('standard workout uses the compact standard pose asset', (
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

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('workout-pose-guide-image')),
    );
    expect(
      (image.image as AssetImage).assetName,
      'assets/images/workout_pose_guide_standard.png',
    );
    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey('workout-pose-guide-opacity')),
          )
          .opacity,
      0.3,
    );
    expect(image.excludeFromSemantics, isTrue);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('workout-pose-guide-image')),
        matching: find.byWidgetPredicate(
          (widget) => widget is IgnorePointer && widget.ignoring,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('narrow workout uses its own tucked-arm pose asset', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WorkoutPoseGuide(exerciseType: ExerciseType.narrowPushup),
      ),
    );

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('workout-pose-guide-image')),
    );
    expect(
      (image.image as AssetImage).assetName,
      'assets/images/workout_pose_guide_narrow.png',
    );
  });

  testWidgets('portrait camera guide stays compact and width-led', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(567, 790);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: WorkoutPoseGuide(exerciseType: ExerciseType.pushup),
      ),
    );

    final frame = tester.getSize(
      find.byKey(const ValueKey('workout-pose-guide-frame')),
    );
    expect(frame.width, lessThanOrEqualTo(567 * 0.9));
    expect(frame.height, lessThanOrEqualTo(790 * 0.62));
    expect(frame.width / frame.height, closeTo(1.15, 0.01));
  });

  testWidgets('wide camera guide respects the shorter stage dimension', (
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
    expect(frame.height, lessThanOrEqualTo(400 * 0.82));
    expect(frame.width / frame.height, closeTo(1.15, 0.01));
    expect(tester.getCenter(frameFinder).dx, closeTo(250, 0.1));
  });
}
