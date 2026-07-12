import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/ui/pose_feedback/pose_silhouette_tracker.dart';

void main() {
  final origin = DateTime.utc(2026, 7, 12);

  group('PoseSilhouetteTracker', () {
    test('stays hidden until observations are stable for 150ms', () {
      final tracker = PoseSilhouetteTracker();

      expect(tracker.update(_valid(origin)), isNull);
      expect(
        tracker.update(_valid(origin.add(const Duration(milliseconds: 149)))),
        isNull,
      );
      expect(
        tracker.update(_valid(origin.add(const Duration(milliseconds: 150)))),
        isNotNull,
      );
    });

    test('smooths small valid movement', () {
      final tracker = PoseSilhouetteTracker();
      tracker.update(_valid(origin));
      final initial = tracker.update(
        _valid(origin.add(const Duration(milliseconds: 150))),
      )!;

      final moved = tracker.update(
        _valid(
          origin.add(const Duration(milliseconds: 183)),
          horizontalShift: 0.1,
        ),
      )!;

      expect(moved.head.x, greaterThan(initial.head.x));
      expect(moved.head.x, lessThan(0.6));
    });

    test('holds the last geometry during a short dropout', () {
      final tracker = PoseSilhouetteTracker();
      tracker.update(_valid(origin));
      final visible = tracker.update(
        _valid(origin.add(const Duration(milliseconds: 150))),
      )!;

      final held = tracker.update(
        HeadShoulderObservation.missing(
          origin.add(const Duration(milliseconds: 350)),
        ),
      );

      expect(held, same(visible));
    });

    test('hides after a continuous 300ms dropout', () {
      final tracker = PoseSilhouetteTracker();
      tracker.update(_valid(origin));
      tracker.update(_valid(origin.add(const Duration(milliseconds: 150))));

      expect(
        tracker.update(
          HeadShoulderObservation.missing(
            origin.add(const Duration(milliseconds: 451)),
          ),
        ),
        isNull,
      );
    });

    test('requires stable observations before reappearing', () {
      final tracker = PoseSilhouetteTracker();
      tracker.update(_valid(origin));
      tracker.update(_valid(origin.add(const Duration(milliseconds: 150))));
      tracker.update(
        HeadShoulderObservation.missing(
          origin.add(const Duration(milliseconds: 451)),
        ),
      );

      expect(
        tracker.update(_valid(origin.add(const Duration(milliseconds: 500)))),
        isNull,
      );
      expect(
        tracker.update(_valid(origin.add(const Duration(milliseconds: 649)))),
        isNull,
      );
      expect(
        tracker.update(_valid(origin.add(const Duration(milliseconds: 650)))),
        isNotNull,
      );
    });

    test('reset removes the previous session geometry', () {
      final tracker = PoseSilhouetteTracker();
      tracker.update(_valid(origin));
      tracker.update(_valid(origin.add(const Duration(milliseconds: 150))));

      tracker.reset();

      expect(
        tracker.update(_valid(origin.add(const Duration(milliseconds: 200)))),
        isNull,
      );
    });
  });
}

HeadShoulderObservation _valid(DateTime at, {double horizontalShift = 0}) {
  return HeadShoulderObservation(
    at: at,
    head: NormalizedPosePoint(0.5 + horizontalShift, 0.25),
    headConfidence: 0.9,
    leftShoulder: NormalizedPosePoint(0.3 + horizontalShift, 0.5),
    leftShoulderConfidence: 0.9,
    rightShoulder: NormalizedPosePoint(0.7 + horizontalShift, 0.5),
    rightShoulderConfidence: 0.9,
  );
}
