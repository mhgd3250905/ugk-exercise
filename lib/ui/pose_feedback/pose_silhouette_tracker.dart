import 'dart:math' as math;

class NormalizedPosePoint {
  const NormalizedPosePoint(this.x, this.y);

  final double x;
  final double y;

  bool get isFinite => x.isFinite && y.isFinite;

  NormalizedPosePoint interpolate(NormalizedPosePoint other, double amount) {
    return NormalizedPosePoint(
      x + (other.x - x) * amount,
      y + (other.y - y) * amount,
    );
  }
}

class HeadShoulderObservation {
  const HeadShoulderObservation({
    required this.at,
    required this.head,
    required this.headConfidence,
    required this.leftShoulder,
    required this.leftShoulderConfidence,
    required this.rightShoulder,
    required this.rightShoulderConfidence,
  });

  const HeadShoulderObservation.missing(this.at)
    : head = null,
      headConfidence = 0,
      leftShoulder = null,
      leftShoulderConfidence = 0,
      rightShoulder = null,
      rightShoulderConfidence = 0;

  final DateTime at;
  final NormalizedPosePoint? head;
  final double headConfidence;
  final NormalizedPosePoint? leftShoulder;
  final double leftShoulderConfidence;
  final NormalizedPosePoint? rightShoulder;
  final double rightShoulderConfidence;
}

class PoseSilhouetteGeometry {
  const PoseSilhouetteGeometry({
    required this.head,
    required this.leftShoulder,
    required this.rightShoulder,
  });

  final NormalizedPosePoint head;
  final NormalizedPosePoint leftShoulder;
  final NormalizedPosePoint rightShoulder;

  PoseSilhouetteGeometry interpolate(
    PoseSilhouetteGeometry other,
    double amount,
  ) {
    return PoseSilhouetteGeometry(
      head: head.interpolate(other.head, amount),
      leftShoulder: leftShoulder.interpolate(other.leftShoulder, amount),
      rightShoulder: rightShoulder.interpolate(other.rightShoulder, amount),
    );
  }
}

class PoseSilhouetteTracker {
  static const confidenceThreshold = 0.3;
  static const appearAfter = Duration(milliseconds: 150);
  static const disappearAfter = Duration(milliseconds: 300);
  static const smoothingTimeConstant = Duration(milliseconds: 120);
  static const largeMovementRatio = 0.35;

  DateTime? _candidateSince;
  DateTime? _lastValidAt;
  DateTime? _lastUpdateAt;
  PoseSilhouetteGeometry? _geometry;
  var _visible = false;

  PoseSilhouetteGeometry? update(HeadShoulderObservation observation) {
    if (!_isValid(observation)) {
      return _handleMissing(observation.at);
    }

    _candidateSince ??= observation.at;
    _lastValidAt = observation.at;
    final next = PoseSilhouetteGeometry(
      head: observation.head!,
      leftShoulder: observation.leftShoulder!,
      rightShoulder: observation.rightShoulder!,
    );
    final previous = _geometry;
    if (previous == null) {
      _geometry = next;
    } else {
      final elapsed = observation.at.difference(_lastUpdateAt!);
      var amount = elapsed <= Duration.zero
          ? 1.0
          : 1 -
                math.exp(
                  -elapsed.inMicroseconds /
                      smoothingTimeConstant.inMicroseconds,
                );
      if (_movementRatio(previous, next) >= largeMovementRatio) {
        amount = math.max(amount, 0.65);
      }
      _geometry = previous.interpolate(next, amount.clamp(0.0, 1.0));
    }
    _lastUpdateAt = observation.at;

    if (!_visible &&
        observation.at.difference(_candidateSince!) >= appearAfter) {
      _visible = true;
    }
    return _visible ? _geometry : null;
  }

  void reset() {
    _candidateSince = null;
    _lastValidAt = null;
    _lastUpdateAt = null;
    _geometry = null;
    _visible = false;
  }

  PoseSilhouetteGeometry? _handleMissing(DateTime at) {
    final lastValidAt = _lastValidAt;
    if (_visible &&
        lastValidAt != null &&
        at.difference(lastValidAt) <= disappearAfter) {
      return _geometry;
    }
    reset();
    return null;
  }

  bool _isValid(HeadShoulderObservation observation) {
    final head = observation.head;
    final leftShoulder = observation.leftShoulder;
    final rightShoulder = observation.rightShoulder;
    return head != null &&
        leftShoulder != null &&
        rightShoulder != null &&
        head.isFinite &&
        leftShoulder.isFinite &&
        rightShoulder.isFinite &&
        observation.headConfidence >= confidenceThreshold &&
        observation.leftShoulderConfidence >= confidenceThreshold &&
        observation.rightShoulderConfidence >= confidenceThreshold &&
        _distance(leftShoulder, rightShoulder) > 0.01;
  }

  double _movementRatio(
    PoseSilhouetteGeometry previous,
    PoseSilhouetteGeometry next,
  ) {
    final shoulderWidth = _distance(
      previous.leftShoulder,
      previous.rightShoulder,
    );
    final largestMovement = math.max(
      _distance(previous.head, next.head),
      math.max(
        _distance(previous.leftShoulder, next.leftShoulder),
        _distance(previous.rightShoulder, next.rightShoulder),
      ),
    );
    return shoulderWidth <= 0
        ? double.infinity
        : largestMovement / shoulderWidth;
  }

  double _distance(NormalizedPosePoint a, NormalizedPosePoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}
