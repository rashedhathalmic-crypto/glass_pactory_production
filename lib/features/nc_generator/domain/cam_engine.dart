import 'dart:math' as math;

import 'dxf_document.dart';

enum ContourKind { hole, internal, external }

sealed class CamSegment {
  const CamSegment();
  DxfPoint get start;
  DxfPoint get end;
  double get length;
}

class CamLine extends CamSegment {
  const CamLine(this.start, this.end);
  @override final DxfPoint start;
  @override final DxfPoint end;
  @override double get length => start.distanceTo(end);
}

class CamArc extends CamSegment {
  const CamArc(this.start, this.end, this.center, this.clockwise, {this.fullCircle = false});
  @override final DxfPoint start;
  @override final DxfPoint end;
  final DxfPoint center;
  final bool clockwise, fullCircle;
  double get radius => center.distanceTo(start);
  double get sweep {
    if (fullCircle) return math.pi * 2;
    final a = math.atan2(start.y - center.y, start.x - center.x);
    final b = math.atan2(end.y - center.y, end.x - center.x);
    var value = clockwise ? a - b : b - a;
    while (value <= 0) value += math.pi * 2;
    return value;
  }
  @override double get length => radius * sweep;
}

class CamContour {
  const CamContour({required this.segments, required this.closed, required this.signedArea, required this.kind, required this.depth});
  final List<CamSegment> segments;
  final bool closed;
  final double signedArea;
  final ContourKind kind;
  final int depth;
  double get length => segments.fold(0.0, (sum, segment) => sum + segment.length);
  DxfPoint get start => segments.first.start;
}

class CamPlan {
  const CamPlan(this.contours, this.warnings);
  final List<CamContour> contours;
  final List<String> warnings;
  double get cuttingLength => contours.fold(0.0, (sum, contour) => sum + contour.length);
  int get holes => contours.where((c) => c.kind == ContourKind.hole).length;
}

/// Converts unordered DXF primitives into connected, nested machining contours.
class CamEngine {
  const CamEngine._();
  static CamPlan analyze(DxfDocument document, {double tolerance = 0.01}) {
    final loose = <CamSegment>[];
    for (final entity in document.entities) {
      if (entity is DxfLine) loose.add(CamLine(entity.start, entity.end));
      if (entity is DxfArc) loose.add(CamArc(entity.start, entity.end, entity.center, entity.clockwise));
      if (entity is DxfCircle) {
        final p = DxfPoint(entity.center.x + entity.radius, entity.center.y);
        loose.add(CamArc(p, p, entity.center, false, fullCircle: true));
      }
      if (entity is DxfPolyline) {
        final count = entity.closed ? entity.vertices.length : entity.vertices.length - 1;
        for (var i = 0; i < count; i++) {
          final a = entity.vertices[i], b = entity.vertices[(i + 1) % entity.vertices.length];
          final bulge = i < entity.bulges.length ? entity.bulges[i] : 0.0;
          loose.add(bulge.abs() < 1e-10 ? CamLine(a, b) : _bulge(a, b, bulge));
        }
      }
    }
    final chains = <List<CamSegment>>[];
    while (loose.isNotEmpty) {
      final chain = <CamSegment>[loose.removeAt(0)];
      var changed = true;
      while (changed && chain.last.end.distanceTo(chain.first.start) > tolerance) {
        changed = false;
        for (var i = 0; i < loose.length; i++) {
          final candidate = loose[i];
          if (chain.last.end.distanceTo(candidate.start) <= tolerance) {
            chain.add(loose.removeAt(i)); changed = true; break;
          }
          if (chain.last.end.distanceTo(candidate.end) <= tolerance) {
            chain.add(_reverse(loose.removeAt(i))); changed = true; break;
          }
        }
      }
      chains.add(chain);
    }
    final warnings = <String>[];
    final records = <({List<CamSegment> segments, bool closed, double area})>[];
    for (final chain in chains) {
      final closed = chain.length == 1 && chain.first is CamArc && (chain.first as CamArc).fullCircle || chain.last.end.distanceTo(chain.first.start) <= tolerance;
      if (!closed) warnings.add('Open contour at X${chain.first.start.x.toStringAsFixed(3)} Y${chain.first.start.y.toStringAsFixed(3)}; machining is blocked.');
      records.add((segments: chain, closed: closed, area: _area(chain)));
    }
    final contours = <CamContour>[];
    for (var itemIndex = 0; itemIndex < records.length; itemIndex++) {
      final item = records[itemIndex];
      var depth = 0;
      if (item.closed) {
        final probe = item.segments.first.start;
        for (var otherIndex = 0; otherIndex < records.length; otherIndex++) {
          final other = records[otherIndex];
          if (itemIndex != otherIndex && other.closed && _contains(other.segments, probe)) depth++;
        }
      }
      final kind = depth == 0 ? ContourKind.external : depth.isOdd ? ContourKind.hole : ContourKind.internal;
      contours.add(CamContour(segments: item.segments, closed: item.closed, signedArea: item.area, kind: kind, depth: depth));
    }
    contours.sort((a, b) { final depth = b.depth.compareTo(a.depth); return depth != 0 ? depth : a.signedArea.abs().compareTo(b.signedArea.abs()); });
    return CamPlan(contours, warnings);
  }

  static CamArc _bulge(DxfPoint a, DxfPoint b, double bulge) {
    final chord = a.distanceTo(b), angle = 4 * math.atan(bulge);
    final radius = chord / (2 * math.sin(angle.abs() / 2));
    final mid = DxfPoint((a.x + b.x) / 2, (a.y + b.y) / 2);
    final offset = chord / (2 * math.tan(angle.abs() / 2));
    final nx = -(b.y - a.y) / chord * offset * bulge.sign;
    final ny = (b.x - a.x) / chord * offset * bulge.sign;
    return CamArc(a, b, DxfPoint(mid.x + nx, mid.y + ny), angle < 0);
  }
  static CamSegment _reverse(CamSegment s) => s is CamLine ? CamLine(s.end, s.start) : CamArc(s.end, s.start, (s as CamArc).center, !s.clockwise, fullCircle: s.fullCircle);
  static CamSegment reverse(CamSegment segment) => _reverse(segment);
  static double _area(List<CamSegment> segments) {
    var area = 0.0;
    for (final s in segments) {
      area += (s.start.x * s.end.y - s.end.x * s.start.y) / 2;
      if (s is CamArc) area += (s.clockwise ? -1 : 1) * (s.radius * s.radius * (s.sweep - math.sin(s.sweep))) / 2;
    }
    return area;
  }
  static bool _contains(List<CamSegment> segments, DxfPoint p) {
    var inside = false;
    final points = <DxfPoint>[];
    for (final s in segments) {
      points.add(s.start);
      if (s is CamArc) {
        final steps = math.max(4, (s.sweep / (math.pi / 18)).ceil());
        final start = math.atan2(s.start.y - s.center.y, s.start.x - s.center.x);
        for (var i = 1; i < steps; i++) {
          final a = start + (s.clockwise ? -1 : 1) * s.sweep * i / steps;
          points.add(DxfPoint(s.center.x + s.radius * math.cos(a), s.center.y + s.radius * math.sin(a)));
        }
      }
    }
    for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
      final a = points[i], b = points[j];
      if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) inside = !inside;
    }
    return inside;
  }
}
