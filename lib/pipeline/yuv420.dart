import 'dart:typed_data';

import 'frame_pipeline.dart';

RgbFrame yuv420ToRgb({
  required int width,
  required int height,
  required Uint8List yPlane,
  required Uint8List uPlane,
  required Uint8List vPlane,
  required int yRowStride,
  required int uvRowStride,
  required int uvPixelStride,
}) {
  final rgb = Uint8List(width * height * 3);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final yValue = yPlane[y * yRowStride + x];
      final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
      final u = uPlane[uvIndex] - 128;
      final v = vPlane[uvIndex] - 128;

      final offset = (y * width + x) * 3;
      rgb[offset] = _clampByte(yValue + 1.402 * v);
      rgb[offset + 1] = _clampByte(yValue - 0.344136 * u - 0.714136 * v);
      rgb[offset + 2] = _clampByte(yValue + 1.772 * u);
    }
  }
  return RgbFrame(width: width, height: height, rgb: rgb);
}

int _clampByte(num value) {
  return value.round().clamp(0, 255);
}
