import 'dart:async';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/platform/camera_service.dart';

const _camera = CameraDescription(
  name: 'test-camera',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 90,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real controller initialization failure disposes its unpublished controller once',
    () async {
      final initializeError = CameraException(
        'initialize_failed',
        'controlled platform failure',
      );
      final platform = _FailingCameraPlatform(initializeError);
      final previousPlatform = CameraPlatform.instance;
      CameraPlatform.instance = platform;
      addTearDown(() => CameraPlatform.instance = previousPlatform);
      final service = CameraService(controllerFactory: _newCameraController);

      await expectLater(
        service.initialize(camera: _camera),
        throwsA(same(initializeError)),
      );

      expect(service.controller, isNull);
      expect(platform.disposeCalls, 1);
    },
  );

  test(
    'cleanup failure does not replace the real initialization error',
    () async {
      final initializeError = CameraException(
        'initialize_failed',
        'controlled platform failure',
      );
      final platform = _FailingCameraPlatform(
        initializeError,
        disposeError: StateError('dispose failed'),
      );
      final previousPlatform = CameraPlatform.instance;
      CameraPlatform.instance = platform;
      addTearDown(() => CameraPlatform.instance = previousPlatform);
      final service = CameraService(controllerFactory: _newCameraController);
      final zoneErrors = <Object>[];

      await runZonedGuarded<Future<void>>(() async {
        await expectLater(
          service.initialize(camera: _camera),
          throwsA(same(initializeError)),
        );
      }, (error, _) => zoneErrors.add(error));

      expect(service.controller, isNull);
      expect(platform.disposeCalls, 1);
      expect(zoneErrors, isEmpty);
    },
  );
}

CameraController _newCameraController(CameraDescription description) {
  return CameraController(
    description,
    ResolutionPreset.medium,
    enableAudio: false,
    imageFormatGroup: ImageFormatGroup.yuv420,
  );
}

class _FailingCameraPlatform extends CameraPlatform {
  _FailingCameraPlatform(this.initializeError, {this.disposeError});

  final Object initializeError;
  final Object? disposeError;
  var disposeCalls = 0;

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async => 1;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        const CameraInitializedEvent(
          1,
          1,
          1,
          ExposureMode.auto,
          false,
          FocusMode.auto,
          false,
        ),
      );

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) => Future<void>.error(initializeError);

  @override
  Future<void> dispose(int cameraId) {
    disposeCalls++;
    final error = disposeError;
    if (error != null) {
      return Future<void>.error(error);
    }
    return Future<void>.value();
  }
}
