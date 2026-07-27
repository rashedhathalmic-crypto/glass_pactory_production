import 'dart:math' as math;

const dxfTolerance = 0.01;

class DxfPoint {
  const DxfPoint(this.x, this.y);
  final double x;
  final double y;
  double distanceTo(DxfPoint other) => math.sqrt(math.pow(x - other.x, 2) + math.pow(y - other.y, 2));
  bool near(DxfPoint other, [double tolerance = dxfTolerance]) => distanceTo(other) <= tolerance;
}

sealed class DxfEntity {
  const DxfEntity();
  Iterable<DxfPoint> get points;
}

class DxfLine extends DxfEntity {
  const DxfLine(this.start, this.end);
  final DxfPoint start;
  final DxfPoint end;
  @override Iterable<DxfPoint> get points => [start, end];
}

class DxfArc extends DxfEntity {
  const DxfArc(this.center, this.radius, this.startAngle, this.endAngle, {this.clockwise = false});
  final DxfPoint center;
  final double radius, startAngle, endAngle;
  final bool clockwise;
  DxfPoint get start => at(startAngle);
  DxfPoint get end => at(endAngle);
  DxfPoint at(double degrees) { final a = degrees * math.pi / 180; return DxfPoint(center.x + radius * math.cos(a), center.y + radius * math.sin(a)); }
  @override Iterable<DxfPoint> get points => [DxfPoint(center.x - radius, center.y - radius), DxfPoint(center.x + radius, center.y + radius), start, end];
}

class DxfCircle extends DxfEntity {
  const DxfCircle(this.center, this.radius);
  final DxfPoint center;
  final double radius;
  @override Iterable<DxfPoint> get points => [DxfPoint(center.x - radius, center.y - radius), DxfPoint(center.x + radius, center.y + radius)];
}

class DxfVertex {
  const DxfVertex(this.point, {this.bulge = 0});
  final DxfPoint point;
  final double bulge;
}

class DxfPolyline extends DxfEntity {
  const DxfPolyline(this.vertices, {this.closed = false});
  final List<DxfVertex> vertices;
  final bool closed;
  @override Iterable<DxfPoint> get points => vertices.map((v) => v.point);
}

sealed class PathSegment {
  const PathSegment();
  DxfPoint get start;
  DxfPoint get end;
  PathSegment reversed();
}
class LineSegment extends PathSegment {
  const LineSegment(this.start, this.end);
  @override final DxfPoint start, end;
  @override LineSegment reversed() => LineSegment(end, start);
}
class ArcSegment extends PathSegment {
  const ArcSegment(this.start, this.end, this.center, {required this.clockwise, this.fullCircle = false});
  @override final DxfPoint start, end;
  final DxfPoint center;
  final bool clockwise, fullCircle;
  double get radius => start.distanceTo(center);
  @override ArcSegment reversed() => ArcSegment(end, start, center, clockwise: !clockwise, fullCircle: fullCircle);
}

class DxfContour {
  const DxfContour({required this.segments, required this.closed, required this.kind, required this.sourceIndex});
  final List<PathSegment> segments;
  final bool closed;
  final ContourKind kind;
  final int sourceIndex;
  DxfPoint get start => segments.first.start;
  double get signedArea {
    var area = 0.0;
    for (final s in segments) {
      if (s is LineSegment) area += s.start.x * s.end.y - s.end.x * s.start.y;
      if (s is ArcSegment) {
        var a1 = math.atan2(s.start.y - s.center.y, s.start.x - s.center.x);
        var a2 = math.atan2(s.end.y - s.center.y, s.end.x - s.center.x);
        var sweep = a2 - a1;
        if (s.fullCircle) sweep = s.clockwise ? -2 * math.pi : 2 * math.pi;
        else if (s.clockwise && sweep >= 0) sweep -= 2 * math.pi;
        else if (!s.clockwise && sweep <= 0) sweep += 2 * math.pi;
        area += s.center.x * (s.end.y - s.start.y) - s.center.y * (s.end.x - s.start.x) + s.radius * s.radius * sweep;
      }
    }
    return area / 2;
  }
}

enum ContourKind { circularHole, internalProfile, externalPerimeter, open }

class DrawingAnalysis {
  const DrawingAnalysis({required this.contours, required this.warnings, required this.minX, required this.maxX, required this.minY, required this.maxY});
  final List<DxfContour> contours;
  final List<String> warnings;
  final double minX, maxX, minY, maxY;
  double get width => maxX - minX;
  double get height => maxY - minY;
}

class DxfDocument {
  const DxfDocument(this.entities, {this.unsupportedEntities = const []});
  final List<DxfEntity> entities;
  final List<String> unsupportedEntities;
  Iterable<DxfPoint> get points => entities.expand((e) => e.points);
}
