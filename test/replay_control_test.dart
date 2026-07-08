import 'package:test/test.dart';
import 'package:ugk_exercise/control/replay_control.dart';

void main() {
  test('tracks replay start pause resume and reset', () {
    final control = ReplayControl();

    expect(control.running, isFalse);
    expect(control.paused, isFalse);
    expect(control.canAdvance, isFalse);

    control.start();
    expect(control.running, isTrue);
    expect(control.canAdvance, isTrue);

    control.pause();
    expect(control.running, isTrue);
    expect(control.paused, isTrue);
    expect(control.canAdvance, isFalse);

    control.resume();
    expect(control.canAdvance, isTrue);

    control.reset();
    expect(control.running, isFalse);
    expect(control.paused, isFalse);
  });

  test('distinguishes requested reset from natural finish', () {
    final control = ReplayControl()..start();

    control.requestReset();
    expect(control.running, isFalse);
    expect(control.paused, isFalse);
    expect(control.resetRequested, isTrue);

    control.reset();
    expect(control.resetRequested, isFalse);
  });
}
