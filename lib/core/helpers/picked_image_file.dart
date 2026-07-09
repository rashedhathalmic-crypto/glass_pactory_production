import 'dart:typed_data';

class PickedImageFile {
  const PickedImageFile({
    required this.fileName,
    required this.bytes,
    required this.contentType,
  });

  final String fileName;
  final Uint8List bytes;
  final String contentType;
}
