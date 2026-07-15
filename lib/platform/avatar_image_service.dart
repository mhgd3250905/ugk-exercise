import 'dart:typed_data';

import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

const avatarImageDimension = 512;
const avatarJpegQuality = 85;

enum AvatarImageSource { gallery, camera }

enum AvatarCropFormat { jpeg }

typedef AvatarCropRequest = ({
  String sourcePath,
  int maxWidth,
  int maxHeight,
  double aspectRatioX,
  double aspectRatioY,
  AvatarCropFormat format,
  int quality,
});
typedef PickAvatarImage = Future<String?> Function(AvatarImageSource source);
typedef CropAvatarImage =
    Future<Uint8List?> Function(AvatarCropRequest request);

class AvatarImageService {
  AvatarImageService({PickAvatarImage? pickImage, CropAvatarImage? cropImage})
    : _pickImage = pickImage ?? _pickAvatarImage,
      _cropImage = cropImage ?? _cropAvatarImage;

  final PickAvatarImage _pickImage;
  final CropAvatarImage _cropImage;

  Future<Uint8List?> pickAndCrop(AvatarImageSource source) async {
    final path = await _pickImage(source);
    if (path == null) return null;
    return _cropImage((
      sourcePath: path,
      maxWidth: avatarImageDimension,
      maxHeight: avatarImageDimension,
      aspectRatioX: 1,
      aspectRatioY: 1,
      format: AvatarCropFormat.jpeg,
      quality: avatarJpegQuality,
    ));
  }
}

Future<String?> _pickAvatarImage(AvatarImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source == AvatarImageSource.gallery
        ? ImageSource.gallery
        : ImageSource.camera,
    requestFullMetadata: false,
  );
  return file?.path;
}

Future<Uint8List?> _cropAvatarImage(AvatarCropRequest request) async {
  final file = await ImageCropper().cropImage(
    sourcePath: request.sourcePath,
    maxWidth: request.maxWidth,
    maxHeight: request.maxHeight,
    aspectRatio: CropAspectRatio(
      ratioX: request.aspectRatioX,
      ratioY: request.aspectRatioY,
    ),
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: request.quality,
  );
  return file?.readAsBytes();
}
