import 'dart:typed_data';

import 'pdf_profile_analysis.dart';

Future<String> convertPdfToDxf({required Uint8List bytes}) {
  throw UnsupportedError('PDF to DXF conversion is available in the web app.');
}

Future<PdfProfileAnalysis> analyzePdfProfiles({required Uint8List bytes}) {
  throw UnsupportedError('PDF profile analysis is available in the web app.');
}

Future<PdfProfileAnalysis> analyzeClipboardDrawing() {
  throw UnsupportedError(
    'Clipboard drawing analysis is available in the web app.',
  );
}

Future<PdfProfileAnalysis> analyzeDrawingImage({
  required Uint8List bytes,
  required String contentType,
}) {
  throw UnsupportedError(
    'Drawing image analysis is available in the web app.',
  );
}

Future<Uint8List> renderPdfFirstPagePng({required Uint8List bytes}) {
  throw UnsupportedError('PDF page rendering is available in the web app.');
}
