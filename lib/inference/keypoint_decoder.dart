import 'dart:typed_data';

import '../pipeline/frame_pipeline.dart';
import '../pushup_domain.dart';

enum TensorValueType { float32, int8, uint8 }

List<double> decodeTensorValues(
  List<int> bytes, {
  required TensorValueType type,
  required double scale,
  required int zeroPoint,
}) {
  return switch (type) {
    TensorValueType.float32 => _decodeFloat32(bytes),
    TensorValueType.int8 =>
      bytes
          .map(
            (byte) =>
                (((byte & 0xff) > 127 ? (byte & 0xff) - 256 : byte & 0xff) -
                    zeroPoint) *
                scale,
          )
          .toList(),
    TensorValueType.uint8 =>
      bytes.map((byte) => ((byte & 0xff) - zeroPoint) * scale).toList(),
  };
}

List<KeyPoint> decodeMoveNetKeypoints(
  List<double> values,
  LetterboxInfo lb, {
  required int width,
  required int height,
}) {
  if (values.length != 17 * 3) {
    throw ArgumentError.value(values.length, 'values.length', 'expected 51');
  }

  return List<KeyPoint>.generate(17, (index) {
    final base = index * 3;
    final yNorm = values[base];
    final xNorm = values[base + 1];
    final x = (xNorm * lb.target - lb.padX) / lb.scale;
    final y = (yNorm * lb.target - lb.padY) / lb.scale;
    return KeyPoint(
      index: index,
      x: _clampDouble(x, 0, width - 1),
      y: _clampDouble(y, 0, height - 1),
      confidence: values[base + 2],
    );
  });
}

double _clampDouble(double value, num min, num max) {
  return value.clamp(min, max).toDouble();
}

List<double> _decodeFloat32(List<int> bytes) {
  if (bytes.length % 4 != 0) {
    throw ArgumentError.value(bytes.length, 'bytes.length', 'must divide by 4');
  }
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  return List<double>.generate(
    bytes.length ~/ 4,
    (index) => data.getFloat32(index * 4, Endian.little),
  );
}
