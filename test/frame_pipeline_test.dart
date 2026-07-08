import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ugk_exercise/pipeline/frame_pipeline.dart';

void main() {
  test('letterbox matches Step0 for 720x1280 frames', () {
    final info = LetterboxInfo.fromSize(width: 720, height: 1280, target: 192);

    expect(info.scale, closeTo(0.15, 1e-9));
    expect(info.newWidth, 108);
    expect(info.newHeight, 192);
    expect(info.padX, 42);
    expect(info.padY, 0);
  });

  test(
    'preprocess letterboxes and quantizes RGB for int8 input without /255 normalization',
    () {
      final frame = RgbFrame(
        width: 2,
        height: 4,
        rgb: Uint8List.fromList([
          0,
          1,
          2,
          255,
          254,
          253,
          3,
          4,
          5,
          252,
          251,
          250,
          6,
          7,
          8,
          249,
          248,
          247,
          9,
          10,
          11,
          246,
          245,
          244,
        ]),
      );
      const pipeline = FramePipeline(
        inputType: InputTensorType.int8,
        inputScale: 1,
        inputZeroPoint: -128,
      );

      final input = pipeline.preprocess(frame, target: 4);

      expect(input.lb.padX, 1);
      expect(input.lb.padY, 0);
      expect(_pixel(input.bytes, target: 4, x: 0, y: 0), [128, 128, 128]);
      expect(_pixel(input.bytes, target: 4, x: 1, y: 0), [128, 129, 130]);
      expect(_pixel(input.bytes, target: 4, x: 2, y: 0), [127, 126, 125]);
      expect(_pixel(input.bytes, target: 4, x: 3, y: 0), [128, 128, 128]);
    },
  );

  test(
    'preprocess passes RGB through unchanged for uint8 non-quantized input',
    () {
      // 实际 MoveNet 模型是 uint8 非量化输入: 直接用 [0,255] 像素值, 不做量化。
      final frame = RgbFrame(
        width: 2,
        height: 4,
        rgb: Uint8List.fromList([
          10,
          20,
          30,
          250,
          240,
          230,
          11,
          21,
          31,
          249,
          239,
          229,
          12,
          22,
          32,
          248,
          238,
          228,
          13,
          23,
          33,
          247,
          237,
          227,
        ]),
      );
      const pipeline = FramePipeline(inputType: InputTensorType.uint8);

      final input = pipeline.preprocess(frame, target: 4);

      // uint8 pad 区应为 0(黑), 而非 int8 的 128。
      expect(_pixel(input.bytes, target: 4, x: 0, y: 0), [0, 0, 0]);
      expect(_pixel(input.bytes, target: 4, x: 3, y: 0), [0, 0, 0]);
      // width=2 经 letterbox( padX=1 ) 后, 图像右列落在 x=2, 含高值像素 230/229。
      // uint8 直通: 高值不被 clamp 到 127(int8 行为), 证明未做量化。
      expect(_pixel(input.bytes, target: 4, x: 2, y: 0).last, greaterThan(127));
    },
  );

  test('orients RGB frames by clockwise rotation then horizontal mirror', () {
    final frame = RgbFrame(
      width: 2,
      height: 3,
      rgb: Uint8List.fromList([
        1,
        1,
        1,
        2,
        2,
        2,
        3,
        3,
        3,
        4,
        4,
        4,
        5,
        5,
        5,
        6,
        6,
        6,
      ]),
    );

    final rotated = orientRgbFrame(frame, rotationDegrees: 90);
    final mirrored = orientRgbFrame(frame, rotationDegrees: 90, mirrorX: true);

    expect(rotated.width, 3);
    expect(rotated.height, 2);
    expect(_pixel(rotated.rgb, target: 3, x: 0, y: 0), [5, 5, 5]);
    expect(_pixel(rotated.rgb, target: 3, x: 2, y: 1), [2, 2, 2]);
    expect(_pixel(mirrored.rgb, target: 3, x: 0, y: 0), [1, 1, 1]);
    expect(_pixel(mirrored.rgb, target: 3, x: 2, y: 1), [6, 6, 6]);
  });
}

List<int> _pixel(
  Uint8List bytes, {
  required int target,
  required int x,
  required int y,
}) {
  final offset = (y * target + x) * 3;
  return [bytes[offset], bytes[offset + 1], bytes[offset + 2]];
}
