import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/helpers/download_helper.dart';
import '../../../core/helpers/file_picker_helper.dart';
import '../../../core/helpers/pdf_to_dxf_helper.dart';
import '../../../core/helpers/picked_file.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/page_header.dart';

class PdfToDxfScreen extends StatefulWidget {
  const PdfToDxfScreen({super.key});

  @override
  State<PdfToDxfScreen> createState() => _PdfToDxfScreenState();
}

class _PdfToDxfScreenState extends State<PdfToDxfScreen> {
  PickedFile? _pdf;
  String? _error;
  bool _busy = false;

  Future<void> _pickAndConvert() async {
    final files = await pickFiles(extensions: const ['pdf']);
    if (files.isEmpty || !mounted) return;
    setState(() {
      _pdf = files.first;
      _busy = true;
      _error = null;
    });
    try {
      final output = await convertPdfToDxf(bytes: _pdf!.bytes);
      final base = _pdf!.fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      await downloadBytes(
        bytes: Uint8List.fromList(utf8.encode(output)),
        fileName: '${base}_PROFILE_ONLY.dxf',
        mimeType: 'application/dxf;charset=utf-8',
      );
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = e.toString()
            .replaceFirst('FormatException: ', '')
            .replaceFirst('Error: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.offWhite,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'PDF → DXF 2D Automatic',
              subtitle: 'Upload PDF — download the millimetre 2D outline only. No text, dimensions, notes, or annotations.',
            ),
            const SizedBox(height: 20),
            AppCard(
              title: 'Automatic profile extraction',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : _pickAndConvert,
                    icon: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.picture_as_pdf),
                    label: Text(_busy ? 'Converting…' : 'Choose PDF and download DXF'),
                  ),
                  if (_pdf != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_pdf!.fileName),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
