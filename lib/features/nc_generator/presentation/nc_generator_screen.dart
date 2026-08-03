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

class NcGeneratorScreen extends StatefulWidget {
  const NcGeneratorScreen({
    super.key,
    this.onProgramGenerated,
  });

  final ValueChanged<String>? onProgramGenerated;

  @override
  State<NcGeneratorScreen> createState() => _NcGeneratorScreenState();
}

class _NcGeneratorScreenState extends State<NcGeneratorScreen> {
  final _tool = TextEditingController(text: '1');
  final _diameter = TextEditingController(text: '97');
  final _thickness = TextEditingController(text: '10');
  final _passes = TextEditingController(text: '5');
  final _cutPerPass = TextEditingController(text: '0.5');
  final _cutZ = TextEditingController(text: '-13');
  final _x = TextEditingController(text: '0');
  final _y = TextEditingController(text: '0');
  final _plunge = TextEditingController(text: '3000');
  final _feed = TextEditingController(text: '1000');
  final _program = TextEditingController(text: 'O0001');

  late final List<TextEditingController> _controllers = [
    _tool,
    _diameter,
    _thickness,
    _passes,
    _cutPerPass,
    _cutZ,
    _x,
    _y,
    _plunge,
    _feed,
    _program,
  ];
  late final Object _dropRegistration;

  DxfDocument? _document;
  String? _fileName;
  String? _error;
  String _output = '';

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(_generate);
    }
    _dropRegistration = registerFileDrop(_load);
  }

  @override
  void dispose() {
    unregisterFileDrop(_dropRegistration);
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  double _doubleValue(TextEditingController controller, String name) {
    final value = double.tryParse(controller.text.replaceAll(',', '.'));
    if (value == null) throw FormatException('$name must be a number.');
    return value;
  }

  int _intValue(TextEditingController controller, String name) {
    final value = int.tryParse(controller.text);
    if (value == null) throw FormatException('$name must be a whole number.');
    return value;
  }

  Future<void> _pick() async {
    final files = await pickFiles(extensions: const ['dxf']);
    if (files.isNotEmpty) _load(files.first);
  }

  void _load(PickedFile file) {
    try {
      final document = DxfParser.parseBytes(file.bytes);
      if (!mounted) return;
      setState(() {
        _document = document;
        _fileName = file.fileName;
        _error = null;
      });
      _generate();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('FormatException: ', '');
      });
    }
  }

  void _generate() {
    if (_document == null) return;
    try {
      final totalPasses = _intValue(_passes, 'Total passes');
      if (totalPasses < 2) {
        throw const FormatException('Total passes must be 2 or more.');
      }

      final output = NcGenerator.generate(
        _document!,
        NcParameters(
          drawingName: _fileName!,
          toolNumber: _intValue(_tool, 'Tool number'),
          toolDiameter: _doubleValue(_diameter, 'Tool diameter'),
          thickness: _doubleValue(_thickness, 'Thickness'),
          totalPasses: totalPasses,
          offsetDistance: _doubleValue(_cutPerPass, 'Cut per pass'),
          cutDepth: _doubleValue(_cutZ, 'Cutting Z').abs(),
          workOffset: 'G58',
          xOffset: _doubleValue(_x, 'X offset'),
          yOffset: _doubleValue(_y, 'Y offset'),
          plungeFeed: _intValue(_plunge, 'Plunge feed'),
          feedRough: _intValue(_feed, 'Rough feed'),
          programNumber: _program.text.trim().toUpperCase(),
        ),
      );

      if (!mounted) return;
      setState(() {
        _output = output;
        _error = null;
      });
      widget.onProgramGenerated?.call(output);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _output = '';
        _error = error
            .toString()
            .replaceFirst('Invalid argument(s): ', '')
            .replaceFirst('FormatException: ', '');
      });
    }
  }

  Future<void> _download() {
    return downloadBytes(
      bytes: Uint8List.fromList(utf8.encode(_output)),
      fileName:
          '${_program.text.trim().toUpperCase()}_${(_fileName ?? 'drawing').replaceAll(RegExp(r'\.dxf$', caseSensitive: false), '')}.nc',
      mimeType: 'text/plain;charset=utf-8',
    );
  }

  void _openSimulator() {
    if (_output.isEmpty) return;
    widget.onProgramGenerated?.call(_output);
    final controller = DefaultTabController.maybeOf(context);
    if (controller != null && controller.length > 2) controller.animateTo(2);
  }

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
                  title: 'DXF to NC Perimeter Grinding',
                  subtitle:
                      'Upload a DXF and generate SKG1625 perimeter-grinding passes with fixed G58.',
                  actions: [
                    OutlinedButton.icon(
                      onPressed: _pick,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload DXF'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _output.isEmpty ? null : _openSimulator,
                      icon: const Icon(Icons.animation),
                      label: const Text('Simulate NC'),
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

  Widget _setup() {
    return AppCard(
      title: 'Perimeter grinding settings (G58)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dropBox(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _field(_tool, 'Tool number')),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  _diameter,
                  'Tool diameter (D) — full diameter',
                  suffix: 'mm',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _field(_thickness, 'Glass thickness', suffix: 'mm'),
              ),
              const SizedBox(width: 12),
              Expanded(child: _field(_passes, 'Total passes')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _field(_cutPerPass, 'Cut per pass', suffix: 'mm'),
              ),
              const SizedBox(width: 12),
              Expanded(child: _field(_cutZ, 'Cutting Z', suffix: 'mm')),
            ],
          ),
          const SizedBox(height: 12),
          _field(_program, 'Program number', numeric: false),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _field(_x, 'X offset', suffix: 'mm')),
              const SizedBox(width: 12),
              Expanded(child: _field(_y, 'Y offset', suffix: 'mm')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _field(_plunge, 'Plunge feed', suffix: 'mm/min'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  _feed,
                  'Rough feed (passes 1–2)',
                  suffix: 'mm/min',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _document == null ? null : _generate,
            icon: const Icon(Icons.precision_manufacturing),
            label: const Text('Generate SKG1625 NC'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          const SizedBox(height: 14),
          const Text(
            'G58 is fixed. Z defaults to -13. Passes 1–2 use rough feed; remaining passes use F2000.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _dropBox() {
    return InkWell(
      onTap: _pick,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.darkBlue.withValues(alpha: .45),
          ),
          borderRadius: BorderRadius.circular(10),
          color: AppColors.darkBlue.withValues(alpha: .04),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.file_upload_outlined,
              size: 34,
              color: AppColors.darkBlue,
            ),
            const SizedBox(height: 8),
            Text(
              _fileName ?? 'Drop a .dxf file here',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              _document == null
                  ? 'or click to choose a file'
                  : '${_document!.entities.length} entities imported',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? suffix,
    bool numeric = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            )
          : TextInputType.text,
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    );
  }

  Widget _right() {
    return Column(
      children: [
        AppCard(
          title: 'Drawing preview',
          child: SizedBox(
            height: 360,
            width: double.infinity,
            child: _document == null
                ? const Center(
                    child: Text('Upload a DXF to preview the drawing.'),
                  )
                : CustomPaint(painter: _DxfPainter(_document!)),
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          title: 'NC program preview',
          child: Container(
            alignment: Alignment.topLeft,
            constraints: const BoxConstraints(minHeight: 260),
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF111827),
            child: SelectableText(
              _output.isEmpty ? 'NC output will appear here.' : _output,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFFE5E7EB),
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DxfPainter extends CustomPainter {
  const _DxfPainter(this.document);

  final DxfDocument document;

  @override
  void paint(Canvas canvas, Size size) {
    final points = document.points.toList();
    if (points.isEmpty) return;

    final minX = points.map((point) => point.x).reduce(math.min);
    final maxX = points.map((point) => point.x).reduce(math.max);
    final minY = points.map((point) => point.y).reduce(math.min);
    final maxY = points.map((point) => point.y).reduce(math.max);
    final scale = math.min(
      (size.width - 24) / math.max(1, maxX - minX),
      (size.height - 24) / math.max(1, maxY - minY),
    );

    Offset mapPoint(DxfPoint point) => Offset(
          12 + (point.x - minX) * scale,
          size.height - 12 - (point.y - minY) * scale,
        );

    final paint = Paint()
      ..color = AppColors.darkBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final entity in document.entities) {
      if (entity is DxfLine) {
        canvas.drawLine(mapPoint(entity.start), mapPoint(entity.end), paint);
      } else if (entity is DxfPolyline) {
        final path = Path()
          ..moveTo(
            mapPoint(entity.vertices.first).dx,
            mapPoint(entity.vertices.first).dy,
          );
        for (final vertex in entity.vertices.skip(1)) {
          path.lineTo(mapPoint(vertex).dx, mapPoint(vertex).dy);
        }
        if (entity.closed) path.close();
        canvas.drawPath(path, paint);
      } else if (entity is DxfCircle) {
        canvas.drawCircle(
          mapPoint(entity.center),
          entity.radius * scale,
          paint,
        );
      } else if (entity is DxfArc) {
        final start = -entity.startAngle * math.pi / 180;
        final sweep =
            -((entity.endAngle - entity.startAngle + 360) % 360) *
                math.pi /
                180;
        canvas.drawArc(
          Rect.fromCircle(
            center: mapPoint(entity.center),
            radius: entity.radius * scale,
          ),
          start,
          sweep,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DxfPainter oldDelegate) {
    return oldDelegate.document != document;
  }
}
