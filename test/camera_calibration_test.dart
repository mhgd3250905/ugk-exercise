import 'package:test/test.dart';
import 'package:ugk_exercise/control/camera_calibration.dart';

void main() {
  test('applies rotation offset and mirror override', () {
    final calibration = CameraCalibration();

    expect(calibration.rotationFor(90), 90);
    expect(calibration.mirrorFor(isFrontFacing: true), isTrue);

    calibration.rotateClockwise();
    expect(calibration.rotationFor(90), 180);

    calibration.toggleMirror(isFrontFacing: true);
    expect(calibration.mirrorFor(isFrontFacing: true), isFalse);

    calibration.reset();
    expect(calibration.rotationFor(90), 90);
    expect(calibration.mirrorFor(isFrontFacing: true), isTrue);
  });
}
