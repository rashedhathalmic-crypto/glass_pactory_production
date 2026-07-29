// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:js' as js;
import 'dart:typed_data';

Future<String> convertPdfToDxf({required Uint8List bytes}) {
  final completer = Completer<String>();
  js.context.callMethod('pdfToDxf2dCallback', [
    bytes,
    js.allowInterop((Object result) => completer.complete(result.toString())),
    js.allowInterop((Object error) => completer.completeError(error.toString())),
  ]);
  return completer.future;
}
