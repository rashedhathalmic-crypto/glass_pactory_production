import 'dart:math' as math;
import 'drawing_analyzer.dart';
import 'dxf_document.dart';

enum CuttingDirection { cw, ccw }
class NcParameters {
  const NcParameters({required this.drawingName, this.programNumber = 'O0001', this.thickness = 10, this.toolNumber = 1, this.toolName = 'JD-8.00', this.toolDiameter = 8, this.spindleSpeed = 10000, this.cuttingFeed = 1200, this.plungeFeed = 300, double safeZ = 20, this.startZ = 0, this.finalDepth = -10, this.depthPerPass = 3, this.direction = CuttingDirection.ccw, this.internalOffset = 0, this.externalOffset = 0, this.coordinateScale = 1, double xOrigin = 0, double yOrigin = 0, this.controllerCompensation = false, this.workOffset = 'G54', double? xOffset, double? yOffset, double? safeHeight}) : xOrigin = xOffset ?? xOrigin, yOrigin = yOffset ?? yOrigin, safeZ = safeHeight ?? safeZ;
  final String drawingName, programNumber, toolName, workOffset;
  final int toolNumber, spindleSpeed, cuttingFeed, plungeFeed;
  final double thickness, toolDiameter, safeZ, startZ, finalDepth, depthPerPass, internalOffset, externalOffset, coordinateScale, xOrigin, yOrigin;
  final CuttingDirection direction; final bool controllerCompensation;
  void validate() { if (!RegExp(r'^O\d{1,8}$').hasMatch(programNumber)) throw ArgumentError('Program number must use the format O0001.'); if (toolNumber <= 0 || toolDiameter <= 0 || thickness <= 0 || depthPerPass <= 0 || coordinateScale <= 0) throw ArgumentError('Thickness, tool, depth per pass and scale must be positive.'); if (safeZ <= startZ) throw ArgumentError('Safe Z must be above Start Z.'); if (finalDepth >= startZ) throw ArgumentError('Final cutting depth must be below Start Z.'); if (spindleSpeed <= 0 || cuttingFeed <= 0 || plungeFeed <= 0) throw ArgumentError('Speeds and feeds must be positive.'); }
}
enum MotionType { rapid, plunge, cutting }
class NcMotion { const NcMotion({required this.line, required this.type, required this.start, required this.end, required this.contour}); final int line, contour; final MotionType type; final ({double x, double y, double z}) start, end; }
class NcProgram { const NcProgram(this.text, this.motions, this.analysis); final String text; final List<NcMotion> motions; final DrawingAnalysis analysis; }

class NcGenerator {
  const NcGenerator._();
  static String generate(DxfDocument document, NcParameters p) => generateProgram(document, p).text;
  static NcProgram generateProgram(DxfDocument document, NcParameters p) {
    p.validate(); final analysis = DrawingAnalyzer.analyze(document), lines = <String>[], motions = <NcMotion>[];
    void add(String s) => lines.add(s);
    add('%'); add(p.programNumber); add('(DXF: ${_safe(p.drawingName)})'); add('(GLASS THICKNESS: ${_n(p.thickness)} MM)'); add('(TOOL: T${p.toolNumber} ${_safe(p.toolName)} DIA ${_n(p.toolDiameter)} MM)');
    add('G90 G17 G21 G40 G49 G80'); add(p.workOffset); add('T${p.toolNumber} M06'); add('S${p.spindleSpeed} M03'); add('G00 Z${_n(p.safeZ)}');
    var pos = (x: 0.0, y: 0.0, z: p.safeZ);
    void motion(String code, ({double x, double y, double z}) next, MotionType type, int contour) { add(code); motions.add(NcMotion(line: lines.length, type: type, start: pos, end: next, contour: contour)); pos = next; }
    final depths = <double>[]; for (var z = p.startZ - p.depthPerPass; z > p.finalDepth; z -= p.depthPerPass) depths.add(z); depths.add(p.finalDepth);
    for (var ci = 0; ci < analysis.contours.length; ci++) {
      final contour = _compensate(analysis.contours[ci], p); if (contour.segments.isEmpty) continue;
      final segments = _orient(contour.segments, contour.closed, p.direction);
      add('(CONTOUR ${ci + 1}: ${contour.kind.name.toUpperCase()})');
      if (p.controllerCompensation && contour.closed) add(contour.kind == ContourKind.externalPerimeter ? 'G42' : 'G41');
      if (pos.z < p.safeZ) motion('G00 Z${_n(p.safeZ)}', (x: pos.x, y: pos.y, z: p.safeZ), MotionType.rapid, ci);
      final start = _point(segments.first.start, p); motion('G00 X${_n(start.x)} Y${_n(start.y)}', (x: start.x, y: start.y, z: p.safeZ), MotionType.rapid, ci);
      for (final depth in depths) {
        motion('G01 Z${_n(depth)} F${p.plungeFeed}', (x: pos.x, y: pos.y, z: depth), MotionType.plunge, ci);
        for (final s in segments) {
          final end = _point(s.end, p);
          if (s is LineSegment) motion('G01 X${_n(end.x)} Y${_n(end.y)} F${p.cuttingFeed}', (x: end.x, y: end.y, z: depth), MotionType.cutting, ci);
          if (s is ArcSegment) { final center = _point(s.center, p), i = center.x - pos.x, j = center.y - pos.y; motion('${s.clockwise ? 'G02' : 'G03'} X${_n(end.x)} Y${_n(end.y)} I${_n(i)} J${_n(j)} F${p.cuttingFeed}', (x: end.x, y: end.y, z: depth), MotionType.cutting, ci); }
        }
        if (depth != depths.last) motion('G00 Z${_n(p.safeZ)}', (x: pos.x, y: pos.y, z: p.safeZ), MotionType.rapid, ci);
      }
      motion('G00 Z${_n(p.safeZ)}', (x: pos.x, y: pos.y, z: p.safeZ), MotionType.rapid, ci);
      if (p.controllerCompensation && contour.closed) add('G40');
    }
    add('M05'); add('G00 Z50'); add('G00 X0 Y0'); add('M30'); add('%');
    return NcProgram('${lines.join('\n')}\n', motions, analysis);
  }
  static List<PathSegment> _orient(List<PathSegment> input, bool closed, CuttingDirection desired) { if (!closed) return input; final area = DxfContour(segments: input, closed: true, kind: ContourKind.open, sourceIndex: 0).signedArea; final reverse = desired == CuttingDirection.cw ? area > 0 : area < 0; return reverse ? input.reversed.map((s) => s.reversed()).toList() : input; }
  static DxfContour _compensate(DxfContour c, NcParameters p) {
    if (!c.closed || p.controllerCompensation) return c;
    final custom = c.kind == ContourKind.externalPerimeter ? p.externalOffset : p.internalOffset;
    final amount = (p.toolDiameter / 2 + custom) * (c.kind == ContourKind.externalPerimeter ? 1 : -1);
    if (amount.abs() < 1e-9) return c;
    if (c.segments.length == 1 && c.segments.first is ArcSegment) { final a = c.segments.first as ArcSegment, r = a.radius + amount; if (r <= 0) throw ArgumentError('Tool is too large for circular hole.'); final start = DxfPoint(a.center.x + r, a.center.y); return DxfContour(segments: [ArcSegment(start, start, a.center, clockwise: a.clockwise, fullCircle: true)], closed: true, kind: c.kind, sourceIndex: c.sourceIndex); }
    // Vertex-normal offset for mixed line/arc profiles; arc centers remain exact and radii change.
    final shifted = <PathSegment>[]; final outward = c.signedArea >= 0 ? -amount : amount;
    for (final s in c.segments) {
      if (s is ArcSegment) { final sign = s.clockwise ? -1 : 1, radius = math.max(.001, s.radius + outward * sign); DxfPoint radial(DxfPoint q) { final d = q.distanceTo(s.center); return DxfPoint(s.center.x + (q.x-s.center.x)*radius/d, s.center.y+(q.y-s.center.y)*radius/d); } shifted.add(ArcSegment(radial(s.start), radial(s.end), s.center, clockwise: s.clockwise, fullCircle: s.fullCircle)); }
      if (s is LineSegment) { final length=s.start.distanceTo(s.end), nx=-(s.end.y-s.start.y)/length*outward, ny=(s.end.x-s.start.x)/length*outward; shifted.add(LineSegment(DxfPoint(s.start.x+nx,s.start.y+ny),DxfPoint(s.end.x+nx,s.end.y+ny))); }
    }
    // Connect offset segment endpoints to make a safe, continuous contour.
    final joined=<PathSegment>[]; for(var i=0;i<shifted.length;i++){ final s=shifted[i], next=shifted[(i+1)%shifted.length]; joined.add(s); if(!s.end.near(next.start)) joined.add(LineSegment(s.end,next.start)); }
    return DxfContour(segments: joined, closed: true, kind: c.kind, sourceIndex: c.sourceIndex);
  }
  static ({double x,double y}) _point(DxfPoint q,NcParameters p)=>(x:q.x*p.coordinateScale+p.xOrigin,y:q.y*p.coordinateScale+p.yOrigin);
  static String _safe(String s)=>s.replaceAll(RegExp(r'[^A-Za-z0-9_. -]'),'_').toUpperCase();
  static String _n(num n)=>(n.abs()<1e-8?0:n).toStringAsFixed(3);
}
