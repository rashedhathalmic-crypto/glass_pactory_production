// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'dart:typed_data';

import 'pdf_profile_analysis.dart';

Future<String> convertPdfToDxf({required Uint8List bytes}) {
  final completer = Completer<String>();
  js.context.callMethod('pdfToDxf2dCallback', [
    bytes,
    js.allowInterop((Object result) => completer.complete(result.toString())),
    js.allowInterop((Object error) => completer.completeError(error.toString())),
  ]);
  return completer.future;
}

Future<PdfProfileAnalysis> analyzePdfProfiles({required Uint8List bytes}) {
  final completer = Completer<PdfProfileAnalysis>();
  js.context.callMethod('pdfAnalyze2dCallback', [
    bytes,
    js.allowInterop((Object result) {
      try {
        final json = jsonDecode(result.toString()) as Map<String, dynamic>;
        completer.complete(PdfProfileAnalysis.fromJson(json));
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }),
    js.allowInterop((Object error) => completer.completeError(error.toString())),
  ]);
  return completer.future;
}

Future<PdfProfileAnalysis> analyzeClipboardDrawing() {
  final completer = Completer<PdfProfileAnalysis>();
  js.context.callMethod('clipboardImageAnalyze2dCallback', [
    js.allowInterop((Object result) {
      try {
        final json = jsonDecode(result.toString()) as Map<String, dynamic>;
        completer.complete(PdfProfileAnalysis.fromJson(json));
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }),
    js.allowInterop((Object error) => completer.completeError(error.toString())),
  ]);
  return completer.future;
}
