import 'package:flutter/material.dart';

import '../pushup_domain.dart';

class OverlayRenderer extends CustomPainter {
  OverlayRenderer({
    required this.keypoints,
    required this.sourceSize,
    this.showGuide = false,
  });

  /// When true, draws a faint alignment guide (shoulder line + wrist marks)
  /// so the user positions their body at a good distance before starting.
  /// Shown only in the pre-ready phase; it never affects counting.
  final bool showGuide;

  static const edges = [
    (0, 1),
    (0, 2),
    (1, 3),
    (2, 4),
    (5, 6),
    (5, 7),
    (7, 9),
    (6, 8),
    (8, 10),
    (5, 11),
    (6, 12),
    (11, 12),
    (11, 13),
    (12, 14),
    (13, 15),
    (14, 16),
  ];

  final List<KeyPoint> keypoints;
  final Size sourceSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (sourceSize.width <= 0 ||
        sourceSize.height <= 0 ||
        keypoints.length < 17) {
      return;
    }
    final sx = size.width / sourceSize.width;
    final sy = size.height / sourceSize.height;
    final linePaint = Paint()
      ..color = Colors.amber
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final green = Paint()..color = Colors.greenAccent;
    final red = Paint()..color = Colors.redAccent;

    Offset point(KeyPoint keypoint) => Offset(keypoint.x * sx, keypoint.y * sy);

    for (final (aIndex, bIndex) in edges) {
      final a = keypoints[aIndex];
      final b = keypoints[bIndex];
      if (a.confidence >= 0.2 && b.confidence >= 0.2) {
        canvas.drawLine(point(a), point(b), linePaint);
      }
    }

    for (final keypoint in keypoints) {
      canvas.drawCircle(
        point(keypoint),
        4,
        keypoint.confidence >= 0.3 ? green : red,
      );
    }

    if (showGuide) {
      _drawGuide(canvas, size);
    }
  }

  /// Draws a faint alignment guide so the user stands far enough that elbows
  /// stay in frame. The guide is a fixed-ratio template (independent of the
  /// detected pose): a head mark, a shoulder line, and two wrist marks. Ratios
  /// are calibrated from a real "good distance" hold (see _pose_capture data):
  ///   nose y≈0.18, shoulders y≈0.29 (x 0.23-0.75), wrists y≈0.69 at the sides
  ///   (x≈0.03 / 0.91). Wrists sit ~0.41 below shoulders because in a pushup the
  ///   hands plant on the floor well below the raised shoulders.
  void _drawGuide(Canvas canvas, Size size) {
    final guide = Paint()
      ..color = const Color(0x88FFFFFF)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Head mark: centered near the top.
    _mark(canvas, guide, Offset(size.width * 0.47, size.height * 0.18));

    // Shoulder line: where the shoulders should rest.
    final shoulderY = size.height * 0.29;
    canvas.drawLine(
      Offset(size.width * 0.23, shoulderY),
      Offset(size.width * 0.75, shoulderY),
      guide,
    );

    // Wrist marks: hands plant on the floor, well below the shoulders, near the
    // frame edges so the elbows have room to bend without leaving the frame.
    final wristY = size.height * 0.69;
    _mark(canvas, guide, Offset(size.width * 0.91, wristY));
    _mark(canvas, guide, Offset(size.width * 0.09, wristY));
  }

  void _mark(Canvas canvas, Paint paint, Offset center) {
    const r = 10.0;
    canvas.drawCircle(center, r, paint);
  }

  @override
  bool shouldRepaint(covariant OverlayRenderer oldDelegate) {
    return oldDelegate.keypoints != keypoints ||
        oldDelegate.sourceSize != sourceSize ||
        oldDelegate.showGuide != showGuide;
  }
}
