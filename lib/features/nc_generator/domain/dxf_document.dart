import 'dart:math' as math;

sealed class DxfEntity {
  const DxfEntity();
  Iterable<DxfPoint> get points;
}

class DxfPoint {
  const DxfPoint(this.x, this.y);
  final double x;
  final double y;
  double distanceTo(DxfPoint other) => math.sqrt(math.pow(x - other.x, 2) + math.pow(y - other.y, 2));
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
  final double radius;
  final double startAngle;
  final double endAngle;
  final bool clockwise;
  DxfPoint get start => _at(startAngle);
  DxfPoint get end => _at(endAngle);
  DxfPoint _at(double degrees) {
    final radians = degrees * math.pi / 180;
    return DxfPoint(center.x + radius * math.cos(radians), center.y + radius * math.sin(radians));
  }
  @override Iterable<DxfPoint> get points => [center, start, end];
}

class DxfCircle extends DxfEntity {
  const DxfCircle(this.center, this.radius);
  final DxfPoint center;
  final double radius;
  @override Iterable<DxfPoint> get points => [
    DxfPoint(center.x - radius, center.y - radius),
    DxfPoint(center.x + radius, center.y + radius),
  ];
}

class DxfPolyline extends DxfEntity {
  const DxfPolyline(this.vertices, {this.closed = false, this.bulges = const []});
  final List<DxfPoint> vertices;
  final bool closed;
  /// Arc bulge at each vertex (tan of one quarter of the included angle).
  final List<double> bulges;
  @override Iterable<DxfPoint> get points => vertices;
}

class DxfDocument {
  const DxfDocument(this.entities, {this.units = DxfUnits.unitless});
  final List<DxfEntity> entities;
  final DxfUnits units;
  Iterable<DxfPoint> get points => entities.expand((entity) => entity.points);
}

enum DxfUnits { unitless, inches, feet, miles, millimeters, centimeters, meters, kilometers, unknown }
