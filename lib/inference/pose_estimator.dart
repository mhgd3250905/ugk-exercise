import 'dart:io';
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../pipeline/frame_pipeline.dart';
import '../pushup_domain.dart';
import 'delegate_mode.dart';
import 'keypoint_decoder.dart';

export 'delegate_mode.dart';

class PoseEstimator {
  Interpreter? _interpreter;
  IsolateInterpreter? _isolate;
  Delegate? _delegate;
  String? _assetPath;

  var _target = 192;
  var _inputType = InputTensorType.uint8;
  var _inputScale = 1.0;
  var _inputZeroPoint = 0;
  var _outputScale = 1.0;
  var _outputZeroPoint = 0;
  var _outputType = TensorValueType.float32;

  int get target => _target;
  InputTensorType get inputType => _inputType;
  double get inputScale => _inputScale;
  int get inputZeroPoint => _inputZeroPoint;

  FramePipeline get pipeline => FramePipeline(
    inputType: _inputType,
    inputScale: _inputScale,
    inputZeroPoint: _inputZeroPoint,
  );

  Future<void> load({
    required String assetPath,
    DelegateMode mode = DelegateMode.cpu,
  }) async {
    await dispose();
    _assetPath = assetPath;

    final options = InterpreterOptions()..threads = 4;
    try {
      _delegate = _delegateFor(mode);
      if (_delegate != null) {
        options.addDelegate(_delegate!);
      }
      if (mode == DelegateMode.nnapi) {
        options.useNnApiForAndroid = true;
      }

      final file = File(assetPath);
      if (await file.exists()) {
        _interpreter = Interpreter.fromFile(file, options: options);
      } else {
        _interpreter = await Interpreter.fromAsset(assetPath, options: options);
      }

      final input = _interpreter!.getInputTensor(0);
      _inputType = _inputTensorType(input.type);
      // MoveNet Lightning 输入支持 uint8(非量化, 实际默认) 与 int8(量化)。
      if (_inputType == InputTensorType.float32) {
        throw UnsupportedError(
          'expected uint8 or int8 MoveNet input, got ${input.type}',
        );
      }
      final shape = input.shape;
      if (shape.length < 3 || shape[1] != shape[2]) {
        throw StateError('expected square MoveNet input, got $shape');
      }
      _target = shape[1];
      // 非量化模型 params 为空, 此处仅对 int8 量化模型有意义; uint8 分支不使用 scale。
      _inputScale = input.params.scale;
      _inputZeroPoint = input.params.zeroPoint;

      final output = _interpreter!.getOutputTensor(0);
      _outputType = _tensorValueType(output.type);
      _outputScale = output.params.scale;
      _outputZeroPoint = output.params.zeroPoint;
      _isolate = await IsolateInterpreter.create(
        address: _interpreter!.address,
      );
    } catch (_) {
      await dispose();
      rethrow;
    } finally {
      options.delete();
    }
  }

  Future<List<KeyPoint>> infer(TensorInput input) async {
    final isolate = _isolate;
    final interpreter = _interpreter;
    if (isolate == null || interpreter == null) {
      throw StateError('PoseEstimator is not loaded');
    }

    final output = Uint8List(interpreter.getOutputTensor(0).numBytes());
    await isolate.run(input.bytes, output);
    final values = decodeTensorValues(
      output,
      type: _outputType,
      scale: _outputScale,
      zeroPoint: _outputZeroPoint,
    );
    return decodeMoveNetKeypoints(
      values,
      input.lb,
      width: input.srcW,
      height: input.srcH,
    );
  }

  Future<void> switchDelegate(DelegateMode mode) async {
    final assetPath = _assetPath;
    if (assetPath == null) {
      throw StateError('PoseEstimator is not loaded');
    }
    final next = PoseEstimator();
    await next.load(assetPath: assetPath, mode: mode);

    await dispose();
    _interpreter = next._interpreter;
    _isolate = next._isolate;
    _delegate = next._delegate;
    _assetPath = next._assetPath;
    _target = next._target;
    _inputScale = next._inputScale;
    _inputZeroPoint = next._inputZeroPoint;
    _outputScale = next._outputScale;
    _outputZeroPoint = next._outputZeroPoint;
    _outputType = next._outputType;

    next._interpreter = null;
    next._isolate = null;
    next._delegate = null;
    next._assetPath = null;
  }

  Future<void> dispose() async {
    await _isolate?.close();
    _isolate = null;
    _interpreter?.close();
    _interpreter = null;
    _delegate?.delete();
    _delegate = null;
    _assetPath = null;
  }
}

Delegate? _delegateFor(DelegateMode mode) {
  return switch (mode) {
    DelegateMode.cpu || DelegateMode.nnapi => null,
    DelegateMode.gpu => GpuDelegateV2(),
  };
}

TensorValueType _tensorValueType(TensorType type) {
  return switch (type) {
    TensorType.float32 => TensorValueType.float32,
    TensorType.int8 => TensorValueType.int8,
    TensorType.uint8 => TensorValueType.uint8,
    _ => throw UnsupportedError('unsupported MoveNet output type: $type'),
  };
}

InputTensorType _inputTensorType(TensorType type) {
  return switch (type) {
    TensorType.uint8 => InputTensorType.uint8,
    TensorType.int8 => InputTensorType.int8,
    TensorType.float32 => InputTensorType.float32,
    _ => throw UnsupportedError('unsupported MoveNet input type: $type'),
  };
}
