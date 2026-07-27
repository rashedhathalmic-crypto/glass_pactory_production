import 'dart:math' as math;

import 'cam_engine.dart';
import 'dxf_document.dart';

/// Produces cutter-centre contours while retaining native circular geometry.
class OffsetEngine {
  const OffsetEngine._();

  static CamContour offset(CamContour source, double distance) {
    if (distance.abs() < 1e-9) return source;
    final outward = source.kind == ContourKind.external ? distance : -distance;
    final side = source.signedArea >= 0 ? -outward : outward;
    if (source.segments.length == 1 && source.segments.single is CamArc) {
      final arc = source.segments.single as CamArc;
      if (arc.fullCircle) {
        final radius = arc.radius + outward;
        if (radius <= 0) throw ArgumentError('Tool/offset is too large for circular contour.');
        final start = DxfPoint(arc.center.x + radius, arc.center.y);
        return _copy(source, [CamArc(start, start, arc.center, arc.clockwise, fullCircle: true)]);
      }
    }

    // Exact parallel offsets for line-only profiles. Intersections trim/extend
    // adjacent elements, so corners do not acquire gaps or duplicate moves.
    if (source.segments.every((segment) => segment is CamLine)) {
      final shifted = source.segments.cast<CamLine>().map((line) {
        final dx = line.end.x - line.start.x, dy = line.end.y - line.start.y;
        final length = math.sqrt(dx * dx + dy * dy);
        final nx = -dy / length * side, ny = dx / length * side;
        return CamLine(DxfPoint(line.start.x + nx, line.start.y + ny), DxfPoint(line.end.x + nx, line.end.y + ny));
      }).toList();
      final vertices = <DxfPoint>[];
      for (var i = 0; i < shifted.length; i++) {
        vertices.add(_intersection(shifted[(i - 1 + shifted.length) % shifted.length], shifted[i]) ?? shifted[i].start);
      }
      return _copy(source, [for (var i = 0; i < vertices.length; i++) CamLine(vertices[i], vertices[(i + 1) % vertices.length])]);
    }

    // Offset arcs concentrically. Short linking lines are preferable to
    // flattening arcs; the cleanup stage removes links below tolerance.
    final pieces = <CamSegment>[];
    for (final segment in source.segments) {
      if (segment is CamLine) {
        final dx = segment.end.x - segment.start.x, dy = segment.end.y - segment.start.y, length = segment.length;
        pieces.add(CamLine(DxfPoint(segment.start.x - dy / length * side, segment.start.y + dx / length * side), DxfPoint(segment.end.x - dy / length * side, segment.end.y + dx / length * side)));
      } else {
        final arc = segment as CamArc;
        final radial = (arc.clockwise ? side : -side);
        final radius = arc.radius + radial;
        if (radius <= 0) throw ArgumentError('Offset collapses an internal arc.');
        DxfPoint project(DxfPoint p) { final dx=p.x-arc.center.x,dy=p.y-arc.center.y,l=math.sqrt(dx*dx+dy*dy); return DxfPoint(arc.center.x+dx/l*radius,arc.center.y+dy/l*radius); }
        pieces.add(CamArc(project(arc.start), project(arc.end), arc.center, arc.clockwise, fullCircle: arc.fullCircle));
      }
    }
    final joined = <CamSegment>[];
    for (var i = 0; i < pieces.length; i++) {
      final current = pieces[i], next = pieces[(i + 1) % pieces.length];
      joined.add(current);
      if (current.end.distanceTo(next.start) > 0.005) joined.add(CamLine(current.end, next.start));
    }
    return _copy(source, joined.where((segment) => segment.length >= 0.005).toList());
  }

  static CamContour _copy(CamContour c, List<CamSegment> segments) => CamContour(segments: segments, closed: true, signedArea: c.signedArea, kind: c.kind, depth: c.depth);
  static DxfPoint? _intersection(CamLine a, CamLine b) {
    final x1=a.start.x,y1=a.start.y,x2=a.end.x,y2=a.end.y,x3=b.start.x,y3=b.start.y,x4=b.end.x,y4=b.end.y;
    final d=(x1-x2)*(y3-y4)-(y1-y2)*(x3-x4); if (d.abs()<1e-10) return null;
    return DxfPoint(((x1*y2-y1*x2)*(x3-x4)-(x1-x2)*(x3*y4-y3*x4))/d,((x1*y2-y1*x2)*(y3-y4)-(y1-y2)*(x3*y4-y3*x4))/d);
  }
}
