import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/helpers/download_helper.dart';
import '../../../core/helpers/file_drop_helper.dart';
import '../../../core/helpers/file_picker_helper.dart';
import '../../../core/helpers/picked_file.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/page_header.dart';
import '../domain/dxf_document.dart';
import '../domain/dxf_parser.dart';
import '../domain/nc_generator.dart';

class NcGeneratorScreen extends StatefulWidget { const NcGeneratorScreen({super.key}); @override State<NcGeneratorScreen> createState() => _State(); }

class _State extends State<NcGeneratorScreen> {
  final _tool = TextEditingController(text: '1'), _diameter = TextEditingController(text: '6'), _thickness = TextEditingController(text: '19'), _offset = TextEditingController(text: 'G54'), _x = TextEditingController(text: '0'), _y = TextEditingController(text: '0'), _plunge = TextEditingController(text: '300'), _feed = TextEditingController(text: '1200'), _program = TextEditingController(text: 'O0001');
  late final List<TextEditingController> _controllers = [_tool, _diameter, _thickness, _offset, _x, _y, _plunge, _feed, _program];
  late final Object _dropRegistration;
  DxfDocument? _document; String? _fileName, _error; String _output = '';

  @override void initState() { super.initState(); for (final c in _controllers) { c.addListener(_generate); } _dropRegistration = registerFileDrop(_load); }
  @override void dispose() { unregisterFileDrop(_dropRegistration); for (final c in _controllers) { c.dispose(); } super.dispose(); }
  double _d(TextEditingController c, String name) { final n = double.tryParse(c.text.replaceAll(',', '.')); if (n == null) throw FormatException('$name must be a number.'); return n; }
  int _i(TextEditingController c, String name) { final n = int.tryParse(c.text); if (n == null) throw FormatException('$name must be a whole number.'); return n; }
  Future<void> _pick() async { final files = await pickFiles(extensions: const ['dxf']); if (files.isNotEmpty) _load(files.first); }
  void _load(PickedFile file) { try { final document = DxfParser.parseBytes(file.bytes); if (!mounted) return; setState(() { _document = document; _fileName = file.fileName; _error = null; }); _generate(); } on Object catch (e) { if (mounted) setState(() => _error = e.toString().replaceFirst('FormatException: ', '')); } }
  void _generate() { if (_document == null) return; try { final output = NcGenerator.generate(_document!, NcParameters(drawingName: _fileName!, toolNumber: _i(_tool, 'Tool number'), toolDiameter: _d(_diameter, 'Tool diameter'), thickness: _d(_thickness, 'Thickness'), workOffset: _offset.text.trim().toUpperCase(), xOffset: _d(_x, 'X offset'), yOffset: _d(_y, 'Y offset'), plungeFeed: _i(_plunge, 'Plunge feed'), cuttingFeed: _i(_feed, 'Cutting feed'), programNumber: _program.text.trim().toUpperCase())); if (mounted) setState(() { _output = output; _error = null; }); } on Object catch (e) { if (mounted) setState(() { _output = ''; _error = e.toString().replaceFirst('Invalid argument(s): ', ''); }); } }
  Future<void> _download() => downloadBytes(bytes: Uint8List.fromList(utf8.encode(_output)), fileName: '${_program.text.trim().toUpperCase()}_${(_fileName ?? 'drawing').replaceAll(RegExp(r'\.dxf$', caseSensitive: false), '')}.nc', mimeType: 'text/plain;charset=utf-8');

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.offWhite,
      child: LayoutBuilder(
        builder: (context, size) {
          final compact = size.maxWidth < 1000;
          return SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 16 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: 'DXF to NC Generator',
                  subtitle:
                      'Upload a DXF and create machine-ready toolpaths entirely in your browser.',
                  actions: [
                    OutlinedButton.icon(
                      onPressed: _pick,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload DXF'),
                    ),
                    FilledButton.icon(
                      onPressed: _output.isEmpty ? null : _download,
                      icon: const Icon(Icons.download),
                      label: const Text('Download NC'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (compact)
                  Column(
                    children: [
                      _setup(),
                      const SizedBox(height: 16),
                      _right(),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 370, child: _setup()),
                      const SizedBox(width: 20),
                      Expanded(child: _right()),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _setup() => AppCard(title: 'Tool settings', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_dropBox(), const SizedBox(height: 16), Row(children: [Expanded(child: _field(_tool, 'Tool number')), const SizedBox(width: 12), Expanded(child: _field(_diameter, 'Tool diameter', suffix: 'mm'))]), const SizedBox(height: 12), Row(children: [Expanded(child: _field(_thickness, 'Glass thickness', suffix: 'mm')), const SizedBox(width: 12), Expanded(child: _field(_offset, 'Work offset', numeric: false))]), const SizedBox(height: 12), Row(children: [Expanded(child: _field(_x, 'X offset', suffix: 'mm')), const SizedBox(width: 12), Expanded(child: _field(_y, 'Y offset', suffix: 'mm'))]), const SizedBox(height: 12), Row(children: [Expanded(child: _field(_plunge, 'Plunge feed', suffix: 'mm/min')), const SizedBox(width: 12), Expanded(child: _field(_feed, 'Cutting feed', suffix: 'mm/min'))]), const SizedBox(height: 12), _field(_program, 'Program number', numeric: false), const SizedBox(height: 16), FilledButton.icon(onPressed: _document == null ? null : _generate, icon: const Icon(Icons.precision_manufacturing), label: const Text('Generate SKG1625 NC')), if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: AppColors.error))), const SizedBox(height: 14), const Text('Your drawing never leaves this device. No server, workbook, or Excel installation is used.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))]));
  Widget _dropBox() => InkWell(onTap: _pick, borderRadius: BorderRadius.circular(10), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(border: Border.all(color: AppColors.darkBlue.withValues(alpha: .45)), borderRadius: BorderRadius.circular(10), color: AppColors.darkBlue.withValues(alpha: .04)), child: Column(children: [const Icon(Icons.file_upload_outlined, size: 34, color: AppColors.darkBlue), const SizedBox(height: 8), Text(_fileName ?? 'Drop a .dxf file here', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(_document == null ? 'or click to choose a file' : '${_document!.entities.length} entities imported', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))])));
  Widget _field(TextEditingController c, String label, {String? suffix, bool numeric = true}) => TextField(controller: c, keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text, decoration: InputDecoration(labelText: label, suffixText: suffix));
  Widget _right() => Column(children: [AppCard(title: 'Drawing preview', child: SizedBox(height: 360, width: double.infinity, child: _document == null ? const Center(child: Text('Upload a DXF to preview the drawing.')) : CustomPaint(painter: _DxfPainter(_document!)))), const SizedBox(height: 16), AppCard(title: 'NC program preview', child: Container(alignment: Alignment.topLeft, constraints: const BoxConstraints(minHeight: 260), padding: const EdgeInsets.all(16), color: const Color(0xFF111827), child: SelectableText(_output.isEmpty ? 'NC output will appear here.' : _output, style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFE5E7EB), height: 1.4))))]);
}

class _DxfPainter extends CustomPainter { const _DxfPainter(this.document); final DxfDocument document; @override void paint(Canvas canvas, Size size) { final points = document.points.toList(); if (points.isEmpty) return; final minX = points.map((p) => p.x).reduce(math.min), maxX = points.map((p) => p.x).reduce(math.max), minY = points.map((p) => p.y).reduce(math.min), maxY = points.map((p) => p.y).reduce(math.max); final scale = math.min((size.width - 24) / math.max(1, maxX - minX), (size.height - 24) / math.max(1, maxY - minY)); Offset pt(DxfPoint p) => Offset(12 + (p.x - minX) * scale, size.height - 12 - (p.y - minY) * scale); final paint = Paint()..color = AppColors.darkBlue..style = PaintingStyle.stroke..strokeWidth = 1.5; for (final e in document.entities) { if (e is DxfLine) canvas.drawLine(pt(e.start), pt(e.end), paint); if (e is DxfPolyline) { final path = Path()..moveTo(pt(e.vertices.first).dx, pt(e.vertices.first).dy); for (final v in e.vertices.skip(1)) { path.lineTo(pt(v).dx, pt(v).dy); } if (e.closed) path.close(); canvas.drawPath(path, paint); } if (e is DxfCircle) canvas.drawCircle(pt(e.center), e.radius * scale, paint); if (e is DxfArc) { final start = -e.startAngle * math.pi / 180, sweep = -((e.endAngle - e.startAngle + 360) % 360) * math.pi / 180; canvas.drawArc(Rect.fromCircle(center: pt(e.center), radius: e.radius * scale), start, sweep, false, paint); } } } @override bool shouldRepaint(covariant _DxfPainter oldDelegate) => oldDelegate.document != document; }
