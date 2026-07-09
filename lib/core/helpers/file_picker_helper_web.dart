// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'picked_file.dart';

Future<List<PickedFile>> pickFiles({
  required List<String> extensions,
  bool allowMultiple = false,
}) async {
  final accept = extensions.map((ext) => '.$ext').join(',');
  final input = html.FileUploadInputElement()
    ..accept = accept
    ..multiple = allowMultiple;

  input.click();
  await input.onChange.first;

  final files = input.files;
  if (files == null || files.isEmpty) return const [];

  final picked = <PickedFile>[];
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
      PickedFile(
        fileName: file.name,
        bytes: bytes,
        contentType: file.type.isNotEmpty ? file.type : 'application/octet-stream',
      ),
    );
  }
  return picked;
}
