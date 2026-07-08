import 'dart:typed_data';

class RgbFrame {
  RgbFrame({required this.width, required this.height, required this.rgb}) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('frame dimensions must be positive');
    }
    final expected = width * height * 3;
    if (rgb.length != expected) {
      throw ArgumentError.value(rgb.length, 'rgb.length', 'expected $expected');
    }
  }

  final int width;
  final int height;
  final Uint8List rgb;
}

RgbFrame orientRgbFrame(
  RgbFrame frame, {
  required int rotationDegrees,
  bool mirrorX = false,
}) {
  final degrees = rotationDegrees % 360;
  if (degrees % 90 != 0) {
    throw ArgumentError.value(
      rotationDegrees,
      'rotationDegrees',
      'must be 0/90/180/270',
    );
  }

  final rotated = switch (degrees) {
    0 => frame,
    90 => _rotate90(frame),
    180 => _rotate180(frame),
    270 => _rotate270(frame),
    _ => frame,
  };
  return mirrorX ? _mirrorX(rotated) : rotated;
}

class LetterboxInfo {
  const LetterboxInfo({
    required this.scale,
    required this.padX,
    required this.padY,
    required this.newWidth,
    required this.newHeight,
    required this.target,
  });

  factory LetterboxInfo.fromSize({
    required int width,
    required int height,
    required int target,
  }) {
    final scale = target / width < target / height
        ? target / width
        : target / height;
    final newWidth = (width * scale).round();
    final newHeight = (height * scale).round();
    return LetterboxInfo(
      scale: scale,
      padX: (target - newWidth) ~/ 2,
      padY: (target - newHeight) ~/ 2,
      newWidth: newWidth,
      newHeight: newHeight,
      target: target,
    );
  }

  final double scale;
  final int padX;
  final int padY;
  final int newWidth;
  final int newHeight;
  final int target;
}

/// MoveNet 输入张量的值类型。决定量化策略与合法字节范围。
enum InputTensorType { int8, uint8, float32 }

class TensorInput {
  const TensorInput({
    required this.bytes,
    required this.target,
    required this.lb,
    required this.srcW,
    required this.srcH,
  });

  final Uint8List bytes;
  final int target;
  final LetterboxInfo lb;
  final int srcW;
  final int srcH;
}

class FramePipeline {
  const FramePipeline({
    required this.inputType,
    this.inputScale = 1.0,
    this.inputZeroPoint = 0,
  });

  /// 输入张量类型，决定量化方式与 clamp 范围。
  final InputTensorType inputType;
  final double inputScale;
  final int inputZeroPoint;

  TensorInput preprocess(RgbFrame frame, {int target = 192}) {
    if (target <= 0) {
      throw ArgumentError.value(target, 'target', 'must be positive');
    }

    final lb = LetterboxInfo.fromSize(
      width: frame.width,
      height: frame.height,
      target: target,
    );
    final out = Uint8List(target * target * 3);
    out.fillRange(0, out.length, _quantize(0));

    for (var y = 0; y < lb.newHeight; y++) {
      final srcY = _sourceCoord(y, frame.height, lb.newHeight);
      final y0 = srcY.floor();
      final y1 = y0 + 1 < frame.height ? y0 + 1 : y0;
      final wy = srcY - y0;
      for (var x = 0; x < lb.newWidth; x++) {
        final srcX = _sourceCoord(x, frame.width, lb.newWidth);
        final x0 = srcX.floor();
        final x1 = x0 + 1 < frame.width ? x0 + 1 : x0;
        final wx = srcX - x0;
        final dstOffset = ((y + lb.padY) * target + x + lb.padX) * 3;
        for (var c = 0; c < 3; c++) {
          final top =
              _rgb(frame, x0, y0, c) * (1 - wx) + _rgb(frame, x1, y0, c) * wx;
          final bottom =
              _rgb(frame, x0, y1, c) * (1 - wx) + _rgb(frame, x1, y1, c) * wx;
          out[dstOffset + c] = _quantize(top * (1 - wy) + bottom * wy);
        }
      }
    }

    return TensorInput(
      bytes: out,
      target: target,
      lb: lb,
      srcW: frame.width,
      srcH: frame.height,
    );
  }

  /// 按输入张量类型把 [0,255] 的 RGB 值映射到合法字节。
  /// - int8 量化: clip(round(v/scale+zp), -128, 127)
  /// - uint8 非量化(MoveNet 实际类型): 直接 clip 到 [0,255]
  /// - float32: clip 到 [0,255] 后按小端字节展开(每像素占4字节, 本版不用于 MoveNet)
  int _quantize(num value) {
    switch (inputType) {
      case InputTensorType.int8:
        final q = (value / inputScale + inputZeroPoint)
            .round()
            .clamp(-128, 127);
        return q & 0xff;
      case InputTensorType.uint8:
        // 非量化模型: 直接用 [0,255] 像素值, 不做量化运算。
        final q = value.round().clamp(0, 255);
        return q & 0xff;
      case InputTensorType.float32:
        return value.round().clamp(0, 255) & 0xff;
    }
  }
}

double _sourceCoord(int dst, int srcSize, int dstSize) {
  final coord = (dst + 0.5) * srcSize / dstSize - 0.5;
  return coord.clamp(0.0, (srcSize - 1).toDouble());
}

int _rgb(RgbFrame frame, int x, int y, int channel) {
  return frame.rgb[(y * frame.width + x) * 3 + channel];
}

RgbFrame _rotate90(RgbFrame frame) {
  final out = Uint8List(frame.rgb.length);
  for (var y = 0; y < frame.height; y++) {
    for (var x = 0; x < frame.width; x++) {
      _copyPixel(
        frame,
        out,
        srcX: x,
        srcY: y,
        dstW: frame.height,
        dstX: frame.height - 1 - y,
        dstY: x,
      );
    }
  }
  return RgbFrame(width: frame.height, height: frame.width, rgb: out);
}

RgbFrame _rotate180(RgbFrame frame) {
  final out = Uint8List(frame.rgb.length);
  for (var y = 0; y < frame.height; y++) {
    for (var x = 0; x < frame.width; x++) {
      _copyPixel(
        frame,
        out,
        srcX: x,
        srcY: y,
        dstW: frame.width,
        dstX: frame.width - 1 - x,
        dstY: frame.height - 1 - y,
      );
    }
  }
  return RgbFrame(width: frame.width, height: frame.height, rgb: out);
}

RgbFrame _rotate270(RgbFrame frame) {
  final out = Uint8List(frame.rgb.length);
  for (var y = 0; y < frame.height; y++) {
    for (var x = 0; x < frame.width; x++) {
      _copyPixel(
        frame,
        out,
        srcX: x,
        srcY: y,
        dstW: frame.height,
        dstX: y,
        dstY: frame.width - 1 - x,
      );
    }
  }
  return RgbFrame(width: frame.height, height: frame.width, rgb: out);
}

RgbFrame _mirrorX(RgbFrame frame) {
  final out = Uint8List(frame.rgb.length);
  for (var y = 0; y < frame.height; y++) {
    for (var x = 0; x < frame.width; x++) {
      _copyPixel(
        frame,
        out,
        srcX: x,
        srcY: y,
        dstW: frame.width,
        dstX: frame.width - 1 - x,
        dstY: y,
      );
    }
  }
  return RgbFrame(width: frame.width, height: frame.height, rgb: out);
}

void _copyPixel(
  RgbFrame frame,
  Uint8List out, {
  required int srcX,
  required int srcY,
  required int dstW,
  required int dstX,
  required int dstY,
}) {
  final src = (srcY * frame.width + srcX) * 3;
  final dst = (dstY * dstW + dstX) * 3;
  out[dst] = frame.rgb[src];
  out[dst + 1] = frame.rgb[src + 1];
  out[dst + 2] = frame.rgb[src + 2];
}
