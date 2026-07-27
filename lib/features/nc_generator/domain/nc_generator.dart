import 'dart:math' as math;

import 'cam_engine.dart';
import 'dxf_document.dart';

class NcParameters {
  const NcParameters({required this.drawingName, this.toolNumber = 1, this.toolDiameter = 6, this.thickness = 19, this.maxPassDepth = 5, this.finishAllowance = 0, this.leadLength = 4, this.workOffset = 'G54', this.xOffset = 0, this.yOffset = 0, this.plungeFeed = 300, this.cuttingFeed = 1200, this.spindleSpeed = 5500, this.safeHeight = 10, this.programNumber = 'O0001'});
  final String drawingName;
  final int toolNumber, plungeFeed, cuttingFeed, spindleSpeed;
  final double toolDiameter, thickness, maxPassDepth, finishAllowance, leadLength, xOffset, yOffset, safeHeight;
  final String workOffset, programNumber;
  void validate() {
    if (toolNumber <= 0 || toolDiameter <= 0 || thickness <= 0 || maxPassDepth <= 0 || safeHeight <= 0 || leadLength < 0) throw ArgumentError('Tool, thickness, step-down and safe height must be positive.');
    if (plungeFeed <= 0 || cuttingFeed <= 0 || spindleSpeed <= 0) throw ArgumentError('Feed rates and spindle speed must be positive.');
    if (!RegExp(r'^G5[4-9]$').hasMatch(workOffset)) throw ArgumentError('Work offset must be G54–G59.');
    if (!RegExp(r'^O\d{1,8}$').hasMatch(programNumber)) throw ArgumentError('Program number must use the format O0001.');
  }
}

class NcGenerator {
  const NcGenerator._();
  static String generate(DxfDocument document, NcParameters p) {
    p.validate();
    final plan = CamEngine.analyze(document);
    if (plan.contours.isEmpty) throw ArgumentError('Upload a DXF drawing first.');
    if (plan.warnings.isNotEmpty) throw ArgumentError('${plan.warnings.join(' ')} Repair the DXF before generating production NC.');
    final passes = (p.thickness / p.maxPassDepth).ceil();
    final out = <String>[
      '%', p.programNumber,
      '(SKG1625 CAM - VERIFIED CLOSED CONTOURS)',
      '(DXF:${_safe(p.drawingName)} UNITS:${document.units.name.toUpperCase()} THK:${_n(p.thickness)}MM)',
      '(REPORT CONTOURS:${plan.contours.length} HOLES:${plan.holes} PASSES:$passes LENGTH:${_n(plan.cuttingLength)}MM)',
      '(TOOL T${p.toolNumber} DIA:${_n(p.toolDiameter)}MM STEP:${_n(p.maxPassDepth)}MM)',
      'G21 G17 G90 G40 G49 G80', p.workOffset, 'T${p.toolNumber} M06',
      'S${p.spindleSpeed} M03', 'G00 G43 Z${_n(p.safeHeight)} H${p.toolNumber.toString().padLeft(2, '0')}',
    ];
    for (var index = 0; index < plan.contours.length; index++) {
      final source = plan.contours[index];
      final contour = _compensate(source, p.toolDiameter / 2 + p.finishAllowance);
      out.add('(CONTOUR ${index + 1} ${source.kind.name.toUpperCase()} DEPTH:${source.depth})');
      for (var pass = 1; pass <= passes; pass++) {
        final z = -math.min(p.thickness, pass * p.maxPassDepth);
        final first = contour.segments.first, start = first.start;
        final tangent = _tangent(first);
        final lead = DxfPoint(start.x - tangent.x * p.leadLength, start.y - tangent.y * p.leadLength);
        out.addAll(['(PASS $pass/$passes Z${_n(z)})', 'G00 Z${_n(p.safeHeight)}', 'G00 X${_x(lead, p)} Y${_y(lead, p)}', 'G01 Z${_n(z)} F${p.plungeFeed}']);
        if (p.leadLength > 0) out.add('G01 X${_x(start, p)} Y${_y(start, p)} F${p.cuttingFeed} (LEAD IN)');
        for (final segment in contour.segments) out.add(_move(segment, p));
        if (p.leadLength > 0) out.add('G01 X${_x(lead, p)} Y${_y(lead, p)} F${p.cuttingFeed} (LEAD OUT)');
        out.add('G00 Z${_n(p.safeHeight)}');
      }
    }
    out.addAll(['G00 Z${_n(p.safeHeight)}', 'M05', 'G49', 'G00 X0 Y0', 'M30', '%']);
    return '${out.join('\n')}\n';
  }

  static CamContour _compensate(CamContour c, double radius) {
    if (radius == 0 || c.segments.any((s) => s is! CamLine)) return _radialCompensate(c, radius);
    final lines = c.segments.cast<CamLine>().toList();
    final external = c.kind == ContourKind.external;
    final leftDistance = (c.signedArea >= 0 ? -1 : 1) * (external ? radius : -radius);
    final shifted = lines.map((l) {
      final length = l.length, nx = -(l.end.y - l.start.y) / length * leftDistance, ny = (l.end.x - l.start.x) / length * leftDistance;
      return CamLine(DxfPoint(l.start.x + nx, l.start.y + ny), DxfPoint(l.end.x + nx, l.end.y + ny));
    }).toList();
    final vertices = <DxfPoint>[];
    for (var i = 0; i < shifted.length; i++) vertices.add(_intersection(shifted[(i - 1 + shifted.length) % shifted.length], shifted[i]) ?? shifted[i].start);
    final result = <CamSegment>[];
    for (var i = 0; i < vertices.length; i++) result.add(CamLine(vertices[i], vertices[(i + 1) % vertices.length]));
    return CamContour(segments: result, closed: true, signedArea: c.signedArea, kind: c.kind, depth: c.depth);
  }
  static CamContour _radialCompensate(CamContour c, double radius) {
    final external = c.kind == ContourKind.external;
    final segments = c.segments.map((s) {
      if (s is! CamArc || !s.fullCircle) return s;
      final r = s.radius + (external ? radius : -radius);
      if (r <= 0) throw ArgumentError('Tool is too large for a circular internal contour.');
      final start = DxfPoint(s.center.x + r, s.center.y);
      return CamArc(start, start, s.center, s.clockwise, fullCircle: true);
    }).toList();
    return CamContour(segments: segments, closed: c.closed, signedArea: c.signedArea, kind: c.kind, depth: c.depth);
  }
  static DxfPoint? _intersection(CamLine a, CamLine b) {
    final x1=a.start.x,y1=a.start.y,x2=a.end.x,y2=a.end.y,x3=b.start.x,y3=b.start.y,x4=b.end.x,y4=b.end.y;
    final d=(x1-x2)*(y3-y4)-(y1-y2)*(x3-x4); if (d.abs()<1e-9) return null;
    return DxfPoint(((x1*y2-y1*x2)*(x3-x4)-(x1-x2)*(x3*y4-y3*x4))/d, ((x1*y2-y1*x2)*(y3-y4)-(y1-y2)*(x3*y4-y3*x4))/d);
  }
  static DxfPoint _tangent(CamSegment s) { if (s is CamLine) { final l=s.length; return DxfPoint((s.end.x-s.start.x)/l,(s.end.y-s.start.y)/l); } final a=s as CamArc, dx=a.start.x-a.center.x,dy=a.start.y-a.center.y,l=a.radius; return a.clockwise?DxfPoint(dy/l,-dx/l):DxfPoint(-dy/l,dx/l); }
  static String _move(CamSegment s, NcParameters p) => s is CamLine ? 'G01 X${_x(s.end,p)} Y${_y(s.end,p)} F${p.cuttingFeed}' : '${(s as CamArc).clockwise?'G02':'G03'} X${_x(s.end,p)} Y${_y(s.end,p)} I${_n(s.center.x-s.start.x)} J${_n(s.center.y-s.start.y)} F${p.cuttingFeed}';
  static String _x(DxfPoint v, NcParameters p) => _n(v.x + p.xOffset);
  static String _y(DxfPoint v, NcParameters p) => _n(v.y + p.yOffset);
  static String _safe(String value) => value.replaceAll(RegExp(r'[^A-Za-z0-9_. -]'), '_').toUpperCase();
  static String _n(num value) => (value.abs() < 0.0000001 ? 0 : value).toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');
}
