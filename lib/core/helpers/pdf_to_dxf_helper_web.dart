import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'pdf_profile_analysis.dart';

@JS('pdfToDxf2d')
external JSPromise<JSString> _pdfToDxf2d(JSUint8Array bytes);

@JS('pdfAnalyze2d')
external JSPromise<JSString> _pdfAnalyze2d(JSUint8Array bytes);

@JS('clipboardImageAnalyze2d')
external JSPromise<JSString> _clipboardImageAnalyze2d();

@JS('drawingImageAnalyze2d')
external JSPromise<JSString> _drawingImageAnalyze2d(
  JSUint8Array bytes,
  JSString contentType,
);

Future<String> convertPdfToDxf({required Uint8List bytes}) async {
  final result = await _pdfToDxf2d(bytes.toJS).toDart;
  return result.toDart;
}

Future<PdfProfileAnalysis> analyzePdfProfiles({
  required Uint8List bytes,
}) async {
  final result = await _pdfAnalyze2d(bytes.toJS).toDart;
  return _decodeAnalysis(result.toDart);
}

Future<PdfProfileAnalysis> analyzeClipboardDrawing() async {
  final result = await _clipboardImageAnalyze2d().toDart;
  return _decodeAnalysis(result.toDart);
}

Future<PdfProfileAnalysis> analyzeDrawingImage({
  required Uint8List bytes,
  required String contentType,
}) async {
  final result = await _drawingImageAnalyze2d(
    bytes.toJS,
    contentType.toJS,
  ).toDart;
  return _decodeAnalysis(result.toDart);
}

PdfProfileAnalysis _decodeAnalysis(String source) {
  final json = jsonDecode(source) as Map<String, dynamic>;
  return PdfProfileAnalysis.fromJson(json);
}
