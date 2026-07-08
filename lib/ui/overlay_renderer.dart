import 'package:flutter/material.dart';

import '../pushup_domain.dart';

class OverlayRenderer extends CustomPainter {
  OverlayRenderer({required this.keypoints, required this.sourceSize});

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
  }

  @override
  bool shouldRepaint(covariant OverlayRenderer oldDelegate) {
    return oldDelegate.keypoints != keypoints ||
        oldDelegate.sourceSize != sourceSize;
  }
}
