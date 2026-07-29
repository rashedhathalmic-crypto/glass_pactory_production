import 'dart:typed_data';

import 'pdf_to_dxf_helper_stub.dart'
    if (dart.library.html) 'pdf_to_dxf_helper_web.dart' as impl;

Future<String> convertPdfToDxf({
  required Uint8List bytes,
  required double lengthMm,
  required double widthMm,
  required double angleDeg,
}) => impl.convertPdfToDxf(
  bytes: bytes,
  lengthMm: lengthMm,
  widthMm: widthMm,
  angleDeg: angleDeg,
);
