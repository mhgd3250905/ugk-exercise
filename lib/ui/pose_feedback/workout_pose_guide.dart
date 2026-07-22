import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../product/exercise_type.dart';

/// Fixed aspect ratio of the guide frame: slightly wider than tall so a full
/// pushup figure fits without cropping its body.
const _guideFrameAspect = 1.15;

/// A reserved overlay layer on the camera stage, positioned between two UI
/// anchors (the top camera controls' bottom edge and the coach bar's top edge).
///
/// Today the frame renders nothing visible: it is a transparent placeholder
/// kept in the tree so a future visual guide image (an exercise-specific pose
/// reference, illustration, etc.) can be dropped in and inherit the anchor
/// alignment for free. The layout logic is the contract; the contents are
/// intentionally absent until a real guide asset arrives.
///
/// When a guide image is added later, place it inside the existing
/// `workout-pose-guide-frame` [SizedBox] with `IgnorePointer` +
/// `ExcludeSemantics` + the desired opacity, mirroring how the camera stage's
/// other overlays behave.
class WorkoutPoseGuide extends StatelessWidget {
  const WorkoutPoseGuide({
    super.key,
    required this.exerciseType,
    this.topAnchorFraction = 0.0,
    this.bottomAnchorFraction = 1.0,
  });

  /// Reserved for future exercise-specific guide assets. Today nothing is
  /// rendered, but the parameter is kept so the call sites and tests already
  /// match the eventual contract.
  final ExerciseType exerciseType;

  /// Upper bound of the guide frame, as a fraction of this widget's height
  /// (0.0 = top edge, 1.0 = bottom edge). When the widget fills the camera
  /// stage, this is where the top controls' bottom edge sits relative to that
  /// stage.
  final double topAnchorFraction;

  /// Lower bound of the guide frame, as a fraction of this widget's height
  /// (0.0 = top edge, 1.0 = bottom edge). When the widget fills the camera
  /// stage, this is where the coach bar's top edge sits relative to that stage.
  final double bottomAnchorFraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth / constraints.maxHeight >= 1.2;
        // Anchor band: the vertical region between the two UI anchors. In wide
        // layouts there are no top/bottom anchors overlaying the stage, so fall
        // back to the stage's own bounds with modest insets.
        final bandTop = isWide
            ? constraints.maxHeight * 0.06
            : constraints.maxHeight * topAnchorFraction.clamp(0.0, 1.0);
        final bandBottom = isWide
            ? constraints.maxHeight * 0.94
            : constraints.maxHeight * bottomAnchorFraction.clamp(0.0, 1.0);
        final bandHeight = (bandBottom - bandTop).clamp(
          1.0,
          constraints.maxHeight,
        );
        final widthFromHeight = bandHeight * _guideFrameAspect;
        final widthLimit = constraints.maxWidth * (isWide ? 0.68 : 0.94);
        final frameWidth = math.min(widthFromHeight, widthLimit);
        final frameHeight = frameWidth / _guideFrameAspect;
        final frameTop = bandTop + (bandHeight - frameHeight) / 2;

        return Stack(
          children: [
            Positioned(
              top: frameTop,
              left: (constraints.maxWidth - frameWidth) / 2,
              child: SizedBox(
                key: const ValueKey('workout-pose-guide-frame'),
                width: frameWidth,
                height: frameHeight,
                // Transparent placeholder: no guide asset is shipped yet. The
                // SizedBox itself is the contract for future content; keep it
                // ignored for hit testing so it never blocks the camera.
                child: const IgnorePointer(child: ColoredBox(color: Color(0x00000000))),
              ),
            ),
          ],
        );
      },
    );
  }
}
