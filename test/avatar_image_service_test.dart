import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/platform/avatar_image_service.dart';

void main() {
  test('selection cancellation skips cropping', () async {
    var cropped = false;
    final service = AvatarImageService(
      pickImage: (_) async => null,
      cropImage: (_) async {
        cropped = true;
        return Uint8List(1);
      },
    );

    expect(await service.pickAndCrop(AvatarImageSource.gallery), isNull);
    expect(cropped, isFalse);
  });

  test('crop cancellation returns null', () async {
    final service = AvatarImageService(
      pickImage: (source) async {
        expect(source, AvatarImageSource.camera);
        return 'camera.jpg';
      },
      cropImage: (_) async => null,
    );

    expect(await service.pickAndCrop(AvatarImageSource.camera), isNull);
  });

  test('crop request is square 512 JPEG at the configured quality', () async {
    AvatarCropRequest? request;
    final service = AvatarImageService(
      pickImage: (_) async => 'selected.heic',
      cropImage: (value) async {
        request = value;
        return Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);
      },
    );

    final bytes = await service.pickAndCrop(AvatarImageSource.gallery);

    expect(bytes, [0xff, 0xd8, 0xff, 0xd9]);
    expect(request?.sourcePath, 'selected.heic');
    expect(request?.maxWidth, 512);
    expect(request?.maxHeight, 512);
    expect(request?.aspectRatioX, 1);
    expect(request?.aspectRatioY, 1);
    expect(request?.format, AvatarCropFormat.jpeg);
    expect(request?.quality, avatarJpegQuality);
  });
}
