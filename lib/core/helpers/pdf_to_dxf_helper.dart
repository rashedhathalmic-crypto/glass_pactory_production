import 'dart:typed_data';

import 'pdf_to_dxf_helper_stub.dart'
    if (dart.library.html) 'pdf_to_dxf_helper_web.dart' as impl;

Future<String> convertPdfToDxf({required Uint8List bytes}) =>
    impl.convertPdfToDxf(bytes: bytes);
