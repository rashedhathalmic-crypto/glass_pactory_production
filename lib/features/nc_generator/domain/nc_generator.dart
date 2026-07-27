import 'dart:math' as math;

import 'cam_engine.dart';
import 'dxf_document.dart';

class NcParameters {
  const NcParameters({required this.drawingName, this.toolNumber = 1, this.toolDiameter = 6, this.toolWidth = 24.3, this.thickness = 19, this.maxPassDepth = 5, this.finishAllowance = 0, this.leadLength = 4, this.workOffset = 'G54', this.xOffset = 0, this.yOffset = 0, this.plungeFeed = 300, this.cuttingFeed = 1200, this.roughingFeed = 1000, this.finishingFeed = 2000, this.spindleSpeed = 5500, this.safeHeight = 10, this.programNumber = 'O0001'});
  final String drawingName;
  final int toolNumber, plungeFeed, cuttingFeed, spindleSpeed;
  final double toolDiameter, toolWidth, thickness, maxPassDepth, finishAllowance, leadLength, xOffset, yOffset, safeHeight;
  final int roughingFeed, finishingFeed;
  final String workOffset, programNumber;
  void validate() {
    if (toolNumber <= 0 || toolDiameter <= 0 || toolWidth <= 0 || thickness <= 0 || maxPassDepth <= 0 || safeHeight <= 0 || leadLength < 0) throw ArgumentError('Tool, thickness, step-down and safe height must be positive.');
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
    // SKG perimeter wheels cut the full glass edge with a sequence of radial
    // takes, rather than with router-style depth passes.  Keeping this decision
    // here also leaves the established small-diameter routing mode unchanged.
    if (p.toolDiameter >= 50 && plan.contours.length == 1) return _grind(plan.contours.single, p);
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

  static String _grind(CamContour source, NcParameters p) {
    final radius = p.toolDiameter / 2;
    final takes = [radius + 1.5, radius + .4, radius + .2, radius];
    final z = -(p.thickness + (p.toolWidth - p.thickness) / 2);
    final contours = takes.map((take) => _canonical(_compensate(source, take))).toList();
    final out = <String>[
      '%', p.programNumber,
      '(PART NAME/NUMBER:${_partName(p.drawingName)}/ THK ${_nc(p.thickness)}MM/PERIMETER)',
      '(TOOL:ØX${_nc(p.toolDiameter)}MM/THK${_nc(p.toolWidth)}MM)',
      'S${p.toolDiameter < 110 ? 5500 : 3800}M03', 'G90G40G49G80G98',
      'G21G00${p.workOffset}G17', 'T${p.toolNumber.toString().padLeft(2, '0')}M06',
      'G90G00G43Z50,0H${p.toolNumber.toString().padLeft(2, '0')}',
      'G90G00X${_nc(-radius)}Y${_nc(-radius - 10)}', 'Z10,0',
      'G01Z${_nc(z)}F3000', '',
      'G01X${_nc(-radius)}Y${_nc(contours.first.segments.first.start.y + p.yOffset)}F${p.roughingFeed}', '',
    ];
    for (var pass = 0; pass < 5; pass++) {
      final takeIndex = math.min(pass, 3);
      final contour = contours[takeIndex];
      final feed = takeIndex < 2 ? p.roughingFeed : p.finishingFeed;
      final first = contour.segments.first.start;
      out.add('G90G01X${_nc(first.x + p.xOffset)}Y${_nc(first.y + p.yOffset)}Z${_nc(z)}${pass == 0 ? '' : 'F$feed'}');
      for (var i = 0; i < contour.segments.length; i++) {
        final segment = contour.segments[i];
        final dz = i == 0 ? 'Z0,3' : i == contour.segments.length ~/ 2 ? 'Z-0,3' : '';
        if (segment is CamLine) {
          out.add('${i == 0 ? 'G91G01' : ''}X${_nc(segment.end.x - segment.start.x)}Y${_nc(segment.end.y - segment.start.y)}$dz');
        } else {
          final arc = segment as CamArc;
          out.add('${i == 0 ? 'G91' : ''}${arc.clockwise ? 'G02' : 'G03'}X${_nc(arc.end.x - arc.start.x)}Y${_nc(arc.end.y - arc.start.y)}I${_nc(arc.center.x - arc.start.x)}J${_nc(arc.center.y - arc.start.y)}$dz');
        }
      }
      out.add('');
    }
    out.addAll(['X5,0Y-5,0', '', 'G90G00X-60,0Y-60,0', 'Z50,0', 'X-400,0Y300,0', 'M05', 'M09', 'G49', 'M30', '%']);
    return '${out.join('\n')}\n';
  }

  /// Reference programs enter on the lower edge and run counter-clockwise.
  static CamContour _canonical(CamContour contour) {
    var segments = contour.segments.toList();
    if (contour.signedArea < 0) segments = segments.reversed.map((s) => CamEngine.reverse(s)).toList();
    var best = 0;
    for (var i = 1; i < segments.length; i++) {
      final a = segments[i], b = segments[best];
      final aRight = a.end.x - a.start.x > 0, bRight = b.end.x - b.start.x > 0;
      if ((aRight && !bRight) || (aRight == bRight && (a.start.y < b.start.y - 1e-7 || (a.start.y - b.start.y).abs() < 1e-7 && a.start.x < b.start.x))) best = i;
    }
    segments = [...segments.skip(best), ...segments.take(best)];
    return CamContour(segments: segments, closed: true, signedArea: contour.signedArea.abs(), kind: contour.kind, depth: contour.depth);
  }

  static String _partName(String name) => name.replaceAll(RegExp(r'\.[dD][xX][fF]$'), '').toUpperCase();
  static String _nc(num value) => '${(value.abs() < 5e-9 ? 0 : value).toStringAsFixed(8).replaceFirst(RegExp(r'\.?0+$'), '')}${value == value.roundToDouble() ? ',0' : ''}'.replaceFirst('.', ',');

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
