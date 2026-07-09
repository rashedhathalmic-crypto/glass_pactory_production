import 'dart:typed_data';

Future<void> downloadBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  throw UnsupportedError('File download is only supported on web');
}
