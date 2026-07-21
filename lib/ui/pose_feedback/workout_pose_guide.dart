import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../product/exercise_type.dart';

const _standardPoseGuideAsset = 'assets/images/workout_pose_guide_standard.png';
const _narrowPoseGuideAsset = 'assets/images/workout_pose_guide_narrow.png';

class WorkoutPoseGuide extends StatelessWidget {
  const WorkoutPoseGuide({super.key, required this.exerciseType});

  final ExerciseType exerciseType;

  @override
  Widget build(BuildContext context) {
    final asset = switch (exerciseType) {
      ExerciseType.pushup => _standardPoseGuideAsset,
      ExerciseType.narrowPushup => _narrowPoseGuideAsset,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth / constraints.maxHeight >= 1.2;
        final widthLimit = constraints.maxWidth * (isWide ? 0.68 : 0.9);
        final heightLimit = constraints.maxHeight * (isWide ? 0.82 : 0.62);
        final frameWidth = math.min(widthLimit, heightLimit * 1.15);
        final frameHeight = frameWidth / 1.15;
        final imageScale = exerciseType == ExerciseType.narrowPushup
            ? 1.12
            : 1.0;

        return Align(
          alignment: const Alignment(0, -0.08),
          child: SizedBox(
            key: const ValueKey('workout-pose-guide-frame'),
            width: frameWidth,
            height: frameHeight,
            child: ClipRect(
              child: Transform.scale(
                scale: imageScale,
                child: IgnorePointer(
                  child: Opacity(
                    key: const ValueKey('workout-pose-guide-opacity'),
                    opacity: 0.3,
                    child: Image.asset(
                      asset,
                      key: const ValueKey('workout-pose-guide-image'),
                      excludeFromSemantics: true,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
