import 'dart:math' as math;
import 'dxf_document.dart';

class DrawingAnalyzer {
  const DrawingAnalyzer._();
  static DrawingAnalysis analyze(DxfDocument document) {
    final loose = <_Chain>[], circles = <_Chain>[];
    var index = 0;
    for (final entity in document.entities) {
      if (entity is DxfCircle) {
        final start = DxfPoint(entity.center.x + entity.radius, entity.center.y);
        circles.add(_Chain([ArcSegment(start, start, entity.center, clockwise: false, fullCircle: true)], index++));
      } else if (entity is DxfLine) {
        loose.add(_Chain([LineSegment(entity.start, entity.end)], index++));
      } else if (entity is DxfArc) {
        loose.add(_Chain([ArcSegment(entity.start, entity.end, entity.center, clockwise: entity.clockwise)], index++));
      } else if (entity is DxfPolyline) {
        final segments = <PathSegment>[];
        final count = entity.closed ? entity.vertices.length : entity.vertices.length - 1;
        for (var i = 0; i < count; i++) { final a = entity.vertices[i], b = entity.vertices[(i + 1) % entity.vertices.length]; segments.add(_bulge(a, b.point)); }
        loose.add(_Chain(segments, index++, forceClosed: entity.closed));
      }
    }
    // Join separate LINE/ARC entities endpoint-to-endpoint without duplicating them.
    var changed = true;
    while (changed) {
      changed = false;
      outer: for (var i = 0; i < loose.length; i++) for (var j = i + 1; j < loose.length; j++) {
        final a = loose[i], b = loose[j];
        if (a.end.near(b.start)) { a.segments.addAll(b.segments); }
        else if (a.end.near(b.end)) { a.segments.addAll(b.segments.reversed.map((s) => s.reversed())); }
        else if (a.start.near(b.end)) { a.segments.insertAll(0, b.segments); }
        else if (a.start.near(b.start)) { a.segments.insertAll(0, b.segments.reversed.map((s) => s.reversed())); }
        else { continue; }
        loose.removeAt(j); changed = true; break outer;
      }
    }
    final all = [...circles, ...loose];
    final closed = all.where((c) => c.closed).toList();
    // Largest absolute-area closed contour is the stock perimeter; nested contours are internal.
    _Chain? perimeter;
    for (final c in closed) if (perimeter == null || c.area.abs() > perimeter.area.abs()) perimeter = c;
    final contours = <DxfContour>[];
    for (final c in all) {
      final kind = !c.closed ? ContourKind.open : c == perimeter ? ContourKind.externalPerimeter : c.segments.length == 1 && c.segments.first is ArcSegment && (c.segments.first as ArcSegment).fullCircle ? ContourKind.circularHole : ContourKind.internalProfile;
      contours.add(DxfContour(segments: c.segments, closed: c.closed, kind: kind, sourceIndex: c.index));
    }
    contours.sort((a, b) => _priority(a.kind).compareTo(_priority(b.kind)));
    final warnings = <String>[];
    if (document.unsupportedEntities.isNotEmpty) warnings.add('Unsupported entities ignored: ${document.unsupportedEntities.join(', ')}.');
    final open = contours.where((c) => !c.closed).length;
    if (open > 0) warnings.add('$open open or broken contour${open == 1 ? '' : 's'} detected; open geometry will be cut without compensation.');
    if (perimeter == null) warnings.add('No closed external perimeter could be identified.');
    final points = document.points.toList();
    return DrawingAnalysis(contours: contours, warnings: warnings, minX: points.map((p) => p.x).reduce(math.min), maxX: points.map((p) => p.x).reduce(math.max), minY: points.map((p) => p.y).reduce(math.min), maxY: points.map((p) => p.y).reduce(math.max));
  }
  static int _priority(ContourKind k) => switch (k) { ContourKind.circularHole => 0, ContourKind.internalProfile => 1, ContourKind.open => 2, ContourKind.externalPerimeter => 3 };
  static PathSegment _bulge(DxfVertex a, DxfPoint end) {
    if (a.bulge.abs() < 1e-10) return LineSegment(a.point, end);
    final chord = a.point.distanceTo(end), theta = 4 * math.atan(a.bulge);
    final midpoint = DxfPoint((a.point.x + end.x) / 2, (a.point.y + end.y) / 2);
    final distance = chord / (2 * math.tan(theta / 2));
    final dx = (end.x - a.point.x) / chord, dy = (end.y - a.point.y) / chord;
    return ArcSegment(a.point, end, DxfPoint(midpoint.x - dy * distance, midpoint.y + dx * distance), clockwise: a.bulge < 0);
  }
}
class _Chain {
  _Chain(this.segments, this.index, {this.forceClosed = false});
  final List<PathSegment> segments; final int index; final bool forceClosed;
  DxfPoint get start => segments.first.start; DxfPoint get end => segments.last.end;
  bool get closed => forceClosed || start.near(end);
  double get area => DxfContour(segments: segments, closed: closed, kind: ContourKind.open, sourceIndex: index).signedArea;
}
