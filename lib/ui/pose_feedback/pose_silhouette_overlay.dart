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

    final head = _offset(geometry.head, size);
    final leftShoulder = _offset(geometry.leftShoulder, size);
    final rightShoulder = _offset(geometry.rightShoulder, size);
    final shoulderWidth = (rightShoulder - leftShoulder).distance;
    if (shoulderWidth <= 0) return;

    final headRadiusX = shoulderWidth * 0.18;
    final headRadiusY = shoulderWidth * 0.23;
    final neckY = head.dy + headRadiusY * 0.82;
    final neckHalfWidth = headRadiusX * 0.42;
    final path = Path()
      ..addOval(
        Rect.fromCenter(
          center: head,
          width: headRadiusX * 2,
          height: headRadiusY * 2,
        ),
      )
      ..moveTo(head.dx - neckHalfWidth, neckY)
      ..cubicTo(
        head.dx - headRadiusX * 0.75,
        neckY + headRadiusY * 0.45,
        leftShoulder.dx + shoulderWidth * 0.12,
        leftShoulder.dy,
        leftShoulder.dx,
        leftShoulder.dy,
      )
      ..moveTo(head.dx + neckHalfWidth, neckY)
      ..cubicTo(
        head.dx + headRadiusX * 0.75,
        neckY + headRadiusY * 0.45,
        rightShoulder.dx - shoulderWidth * 0.12,
        rightShoulder.dy,
        rightShoulder.dx,
        rightShoulder.dy,
      );

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

  Offset _offset(NormalizedPosePoint point, Size size) {
    return Offset(point.x * size.width, point.y * size.height);
  }

  @override
  bool shouldRepaint(PoseSilhouettePainter oldDelegate) {
    return geometry != oldDelegate.geometry || color != oldDelegate.color;
  }
}
