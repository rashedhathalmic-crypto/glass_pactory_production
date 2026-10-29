import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/helpers/file_picker_helper.dart';
import '../domain/cam_engine.dart';
import '../domain/dxf_document.dart';
import '../domain/dxf_parser.dart';
import '../domain/glass_cutting_planner.dart';

/// Cutting V2: DXF geometry inspection only; no machine-code output.
class GlassCuttingScreen extends StatefulWidget {
  const GlassCuttingScreen({super.key});
  @override
  State<GlassCuttingScreen> createState() => _GlassCuttingScreenState();
}

class _GlassCuttingScreenState extends State<GlassCuttingScreen> {
  final _diameter = TextEditingController(text: '8');
  DxfDocument? _document;
  GlassCuttingPlan? _plan;
  String? _fileName;
  String? _error;
  bool _retainInterior = true;

  @override
  void dispose() {
    _diameter.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    try {
      final files = await pickFiles(extensions: const ['dxf']);
      if (files.isEmpty) return;
      final doc = DxfParser.parseBytes(files.first.bytes);
      if (!mounted) return;
      _document = doc;
      _fileName = files.first.fileName;
      _calculate();
    } catch (error) {
      if (mounted) setState(() { _error = '$error'; _plan = null; });
    }
  }

  void _calculate() {
    if (_document == null) return;
    try {
      final diameter = double.parse(_diameter.text.replaceAll(',', '.'));
      final plan = GlassCuttingPlanner.previewDocument(
        _document!, toolDiameterMm: diameter, retainInterior: _retainInterior);
      setState(() { _plan = plan; _error = null; });
    } catch (error) {
      setState(() { _plan = null; _error = '$error'; });
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text('Cutting V2 - DXF Preview',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Development only. Tool offset preview is not a validated machine path.'),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(onPressed: _upload,
              icon: const Icon(Icons.upload_file), label: const Text('Upload DXF')),
          SizedBox(width: 170, child: TextField(
            controller: _diameter,
            decoration: const InputDecoration(labelText: 'Tool diameter (mm)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _calculate(),
          )),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Keep inside')),
              ButtonSegment(value: false, label: Text('Cut opening')),
            ],
            selected: {_retainInterior},
            onSelectionChanged: (values) {
              setState(() => _retainInterior = values.first);
              _calculate();
            },
          ),
        ],
      ),
      if (_fileName != null) Padding(
        padding: const EdgeInsets.only(top: 12), child: Text('File: $_fileName')),
      if (_error != null) Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(_error!, style: const TextStyle(color: Colors.red))),
      if (_plan != null) ...[
        const SizedBox(height: 16),
        Text('Contours: ${_plan!.paths.length}'),
        const SizedBox(height: 8),
        SizedBox(height: 440, child: Card(
          clipBehavior: Clip.antiAlias,
          child: CustomPaint(painter: _CutPreviewPainter(_plan!.paths),
              child: const SizedBox.expand()),
        )),
        const SizedBox(height: 12),
        for (final warning in _plan!.warnings)
          Padding(padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $warning')),
      ],
      const SizedBox(height: 16),
      const Text('NC export disabled: edge entry, stock boundary, clamps, Z, '
          'cooling and machine settings require verification.'),
    ],
  );
}

class _CutPreviewPainter extends CustomPainter {
  const _CutPreviewPainter(this.contours);
  final List<CamContour> contours;

  List<DxfPoint> _sample(CamContour contour) {
    final result = <DxfPoint>[];
    for (final segment in contour.segments) {
      result.add(segment.start);
      if (segment is CamLine) {
        result.add(segment.end);
      } else if (segment is CamArc) {
        final a = math.atan2(segment.start.y - segment.center.y,
            segment.start.x - segment.center.x);
        final steps = math.max(24, (segment.sweep * 36).ceil());
        for (var i = 1; i <= steps; i++) {
          final angle = a + (segment.clockwise ? -1 : 1) *
              segment.sweep * i / steps;
          result.add(DxfPoint(segment.center.x + segment.radius * math.cos(angle),
              segment.center.y + segment.radius * math.sin(angle)));
        }
      }
    }
    return result;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paths = contours.map(_sample).where((p) => p.isNotEmpty).toList();
    if (paths.isEmpty) return;
    final points = paths.expand((p) => p).toList();
    final minX = points.map((p) => p.x).reduce(math.min);
    final maxX = points.map((p) => p.x).reduce(math.max);
    final minY = points.map((p) => p.y).reduce(math.min);
    final maxY = points.map((p) => p.y).reduce(math.max);
    final scale = math.min((size.width - 32) / math.max(maxX - minX, 1),
        (size.height - 32) / math.max(maxY - minY, 1));
    Offset project(DxfPoint p) => Offset(16 + (p.x - minX) * scale,
        size.height - 16 - (p.y - minY) * scale);
    final pen = Paint()..color = Colors.blue..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final vertices in paths) {
      final first = project(vertices.first);
      final path = Path()..moveTo(first.dx, first.dy);
      for (final point in vertices.skip(1)) {
        final p = project(point);
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, pen);
    }
  }

  @override
  bool shouldRepaint(covariant _CutPreviewPainter old) =>
      old.contours != contours;
}
