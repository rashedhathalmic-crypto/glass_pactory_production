// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

Future<String> convertPdfToDxf({required Uint8List bytes}) async {
  final result = js.context.callMethod<Object>('pdfToDxf2d', [bytes]);
  return (await js_util.promiseToFuture<Object>(result)).toString();
}
