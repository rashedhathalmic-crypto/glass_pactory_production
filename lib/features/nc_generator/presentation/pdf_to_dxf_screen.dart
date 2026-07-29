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
  final _length = TextEditingController();
  final _width = TextEditingController();
  final _angle = TextEditingController(text: '0');
  PickedFile? _pdf;
  String? _error;
  bool _busy = false;

  double _number(TextEditingController controller, String name) {
    final value = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    if (value == null) throw FormatException('$name must be a number.');
    return value;
  }

  Future<void> _pickPdf() async {
    final files = await pickFiles(extensions: const ['pdf']);
    if (files.isEmpty || !mounted) return;
    setState(() {
      _pdf = files.first;
      _error = null;
    });
  }

  Future<void> _convert() async {
    if (_pdf == null) {
      setState(() => _error = 'Choose a PDF first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final length = _number(_length, 'Length');
      final width = _number(_width, 'Width');
      final angle = _number(_angle, 'Angle');
      if (length <= 0 || width <= 0) {
        throw const FormatException('Length and width must be greater than zero.');
      }
      final output = await convertPdfToDxf(
        bytes: _pdf!.bytes,
        lengthMm: length,
        widthMm: width,
        angleDeg: angle,
      );
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
  void dispose() {
    _length.dispose();
    _width.dispose();
    _angle.dispose();
    super.dispose();
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
              title: 'PDF → DXF 2D',
              subtitle: 'Outer profile only — millimetres — no text, dimensions, notes, or annotations.',
            ),
            const SizedBox(height: 20),
            AppCard(
              title: '2D profile dimensions',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text(_pdf?.fileName ?? 'Choose PDF'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _field(_length, 'Length', 'mm')),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_width, 'Width', 'mm')),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_angle, 'Rotation angle', '°')),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _busy ? null : _convert,
                    icon: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download),
                    label: const Text('Convert and download DXF'),
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

  Widget _field(TextEditingController controller, String label, String suffix) => TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(labelText: label, suffixText: suffix),
      );
}
