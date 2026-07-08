import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ugk_exercise/pipeline/yuv420.dart';

void main() {
  test('converts neutral YUV420 pixels to grayscale RGB', () {
    final frame = yuv420ToRgb(
      width: 2,
      height: 2,
      yPlane: Uint8List.fromList([10, 20, 30, 40]),
      uPlane: Uint8List.fromList([128]),
      vPlane: Uint8List.fromList([128]),
      yRowStride: 2,
      uvRowStride: 1,
      uvPixelStride: 1,
    );

    expect(frame.rgb, [10, 10, 10, 20, 20, 20, 30, 30, 30, 40, 40, 40]);
  });
}
