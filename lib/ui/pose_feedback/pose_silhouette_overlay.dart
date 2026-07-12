import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'pose_silhouette_tracker.dart';

class PoseSilhouetteOverlay extends StatefulWidget {
  const PoseSilhouetteOverlay({super.key, required this.observation});

  final HeadShoulderObservation observation;

  @override
  State<PoseSilhouetteOverlay> createState() => _PoseSilhouetteOverlayState();
}

class _PoseSilhouetteOverlayState extends State<PoseSilhouetteOverlay> {
  final _tracker = PoseSilhouetteTracker();
  PoseSilhouetteGeometry? _geometry;

  @override
  void initState() {
    super.initState();
    _geometry = _tracker.update(widget.observation);
  }

  @override
  void didUpdateWidget(PoseSilhouetteOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _geometry = _tracker.update(widget.observation);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        key: const ValueKey('pose-silhouette-canvas'),
        painter: PoseSilhouettePainter(geometry: _geometry),
      ),
    );
  }
}

class PoseSilhouettePainter extends CustomPainter {
  const PoseSilhouettePainter({required this.geometry, this.color = green});

  final PoseSilhouetteGeometry? geometry;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = this.geometry;
    if (geometry == null || size.isEmpty) return;

    final leftShoulder = _offset(geometry.leftShoulder, size);
    final rightShoulder = _offset(geometry.rightShoulder, size);
    final shoulderWidth = (rightShoulder - leftShoulder).distance;
    if (shoulderWidth <= 0) return;

    final path = debugPathFor(size);
    final lineWidth = math.max(2.5, shoulderWidth * 0.018);
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineWidth * 2.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @visibleForTesting
  Path debugPathFor(Size size) {
    final geometry = this.geometry;
    if (geometry == null || size.isEmpty) return Path();

    final head = _offset(geometry.head, size);
    final leftShoulder = _offset(geometry.leftShoulder, size);
    final rightShoulder = _offset(geometry.rightShoulder, size);
    final shoulderWidth = (rightShoulder - leftShoulder).distance;
    final radiusX = shoulderWidth * 0.18;
    final radiusY = shoulderWidth * 0.23;
    final cross = Offset(head.dx, head.dy + radiusY * 1.18);

    return Path()
      ..moveTo(leftShoulder.dx, leftShoulder.dy)
      ..cubicTo(
        leftShoulder.dx + shoulderWidth * 0.18,
        leftShoulder.dy - radiusY * 0.15,
        head.dx - radiusX * 0.35,
        cross.dy + radiusY * 0.1,
        cross.dx,
        cross.dy,
      )
      ..cubicTo(
        head.dx + radiusX * 0.32,
        cross.dy - radiusY * 0.18,
        head.dx + radiusX * 0.92,
        head.dy + radiusY * 0.42,
        head.dx + radiusX * 0.98,
        head.dy + radiusY * 0.02,
      )
      ..cubicTo(
        head.dx + radiusX,
        head.dy - radiusY * 0.6,
        head.dx + radiusX * 0.52,
        head.dy - radiusY,
        head.dx,
        head.dy - radiusY,
      )
      ..cubicTo(
        head.dx - radiusX * 0.52,
        head.dy - radiusY,
        head.dx - radiusX,
        head.dy - radiusY * 0.6,
        head.dx - radiusX * 0.98,
        head.dy + radiusY * 0.02,
      )
      ..cubicTo(
        head.dx - radiusX * 0.92,
        head.dy + radiusY * 0.42,
        head.dx - radiusX * 0.32,
        cross.dy - radiusY * 0.18,
        cross.dx,
        cross.dy,
      )
      ..cubicTo(
        head.dx + radiusX * 0.35,
        cross.dy + radiusY * 0.1,
        rightShoulder.dx - shoulderWidth * 0.18,
        rightShoulder.dy - radiusY * 0.15,
        rightShoulder.dx,
        rightShoulder.dy,
      );
  }

  Offset _offset(NormalizedPosePoint point, Size size) {
    return Offset(point.x * size.width, point.y * size.height);
  }

  @override
  bool shouldRepaint(PoseSilhouettePainter oldDelegate) {
    return geometry != oldDelegate.geometry || color != oldDelegate.color;
  }
}
