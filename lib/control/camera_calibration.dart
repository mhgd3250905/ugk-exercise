class CameraCalibration {
  var rotationOffsetDegrees = 0;
  bool? mirrorOverride;

  int rotationFor(int sensorOrientation) {
    return (sensorOrientation + rotationOffsetDegrees) % 360;
  }

  bool mirrorFor({required bool isFrontFacing}) {
    return mirrorOverride ?? isFrontFacing;
  }

  void rotateClockwise() {
    rotationOffsetDegrees = (rotationOffsetDegrees + 90) % 360;
  }

  void toggleMirror({required bool isFrontFacing}) {
    mirrorOverride = !mirrorFor(isFrontFacing: isFrontFacing);
  }

  void reset() {
    rotationOffsetDegrees = 0;
    mirrorOverride = null;
  }
}
