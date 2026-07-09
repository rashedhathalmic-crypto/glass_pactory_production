// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'picked_image_file.dart';

Future<List<PickedImageFile>> pickImages({bool allowMultiple = true}) async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = allowMultiple;

  input.click();
  await input.onChange.first;

  final files = input.files;
  if (files == null || files.isEmpty) return const [];

  final picked = <PickedImageFile>[];
  for (var i = 0; i < files.length; i++) {
    final file = files[i];
    final reader = html.FileReader();
    final completer = Completer<Uint8List>();
    reader.onLoadEnd.listen((_) {
      completer.complete(reader.result as Uint8List);
    });
    reader.readAsArrayBuffer(file);
    final bytes = await completer.future;
    picked.add(
      PickedImageFile(
        fileName: file.name,
        bytes: bytes,
        contentType: file.type.isNotEmpty ? file.type : 'image/jpeg',
      ),
    );
  }
  return picked;
}
