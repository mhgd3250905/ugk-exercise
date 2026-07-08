import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

class CameraService {
  CameraController? _controller;
  StreamController<CameraImage>? _images;
  CameraDescription? _description;

  Future<List<CameraDescription>> listCameras() async {
    WidgetsFlutterBinding.ensureInitialized();
    return availableCameras();
  }

  Future<void> initialize({
    CameraDescription? camera,
    CameraLensDirection facing = CameraLensDirection.front,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    final cameras = camera == null
        ? await listCameras()
        : const <CameraDescription>[];
    _description =
        camera ??
        cameras.firstWhere(
          (camera) => camera.lensDirection == facing,
          orElse: () => cameras.first,
        );
    final controller = CameraController(
      _description!,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await controller.initialize();
    _controller = controller;
  }

  Stream<CameraImage> get imageStream {
    final controller = _controller;
    if (controller == null) {
      throw StateError('CameraService is not initialized');
    }
    _images ??= StreamController<CameraImage>.broadcast(
      onListen: () {
        if (!controller.value.isStreamingImages) {
          unawaited(controller.startImageStream(_images!.add));
        }
      },
      onCancel: () {
        if (!(_images?.hasListener ?? false) &&
            controller.value.isStreamingImages) {
          unawaited(controller.stopImageStream());
        }
      },
    );
    return _images!.stream;
  }

  CameraController? get controller => _controller;
  CameraDescription? get description => _description;
  Size? get previewSize => _controller?.value.previewSize;
  int get sensorOrientation => _description?.sensorOrientation ?? 0;
  bool get isFrontFacing =>
      _description?.lensDirection == CameraLensDirection.front;

  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.dispose();
    }
    await _images?.close();
    _images = null;
  }
}
