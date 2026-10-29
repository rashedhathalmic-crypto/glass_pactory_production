import 'dart:math' as math;
import 'cam_engine.dart';
import 'dxf_document.dart';

/// Stock rectangle in DXF millimetres.
class GlassStock {
  const GlassStock(this.minX, this.minY, this.maxX, this.maxY);
  final double minX, minY, maxX, maxY;
  bool get valid => [minX,minY,maxX,maxY].every((v)=>v.isFinite) &&
      maxX>minX && maxY>minY;
  bool contains(DxfPoint p) => p.x>=minX && p.x<=maxX &&
      p.y>=minY && p.y<=maxY;
}

class EdgeEntryPreview {
  const EdgeEntryPreview(this.start, this.entry, this.contour,
      this.warnings);
  final DxfPoint start, entry;
  final CamContour contour;
  final List<String> warnings;
}

/// Plans a geometric lead from the nearest sheet edge to a closed contour.
/// This is not a collision-free or machine-certified toolpath.
class GlassEdgeEntryPlanner {
  const GlassEdgeEntryPlanner._();

  static EdgeEntryPreview preview(CamContour contour, GlassStock stock,
      {double toolDiameterMm = 8}) {
    if (!stock.valid || !toolDiameterMm.isFinite || toolDiameterMm<=0 ||
        !contour.closed || contour.segments.isEmpty) {
      throw ArgumentError('Invalid stock, cutter or contour');
    }
    final samples = <DxfPoint>[];
    for (final s in contour.segments) {
      samples.add(s.start);
      if (s is CamLine) samples.add(s.end);
      if (s is CamArc) {
        final startAngle = math.atan2(s.start.y-s.center.y,
            s.start.x-s.center.x);
        final steps = math.max(36,(s.sweep*48).ceil());
        for(var i=0;i<=steps;i++){
          final a=startAngle+(s.clockwise?-1:1)*s.sweep*i/steps;
          samples.add(DxfPoint(s.center.x+s.radius*math.cos(a),
              s.center.y+s.radius*math.sin(a)));
        }
      }
    }
    final radius=toolDiameterMm/2;
    DxfPoint? bestPoint, bestEdge;
    var bestDistance=double.infinity;
    for(final point in samples){
      if(!stock.contains(point)) continue;
      final options=<DxfPoint>[
        DxfPoint(stock.minX-radius,point.y),
        DxfPoint(stock.maxX+radius,point.y),
        DxfPoint(point.x,stock.minY-radius),
        DxfPoint(point.x,stock.maxY+radius),
      ];
      for(final edge in options){
        final distance=point.distanceTo(edge);
        if(distance<bestDistance){
          bestDistance=distance;bestPoint=point;bestEdge=edge;
        }
      }
    }
    if(bestPoint==null || bestEdge==null){
      throw StateError('No offset path point inside stock bounds');
    }
    return EdgeEntryPreview(bestEdge,bestPoint,contour,const [
      'Geometric straight entry only; intersection with other contours is not checked.',
      'Clamp, stock thickness, kerf, coolant and Z clearance are not verified.',
      'Entry from edge is NOT certified safe for machine execution.',
    ]);
  }
}

/// Human-readable motion review, not machine executable G-code.
class CuttingMotionReview {
  const CuttingMotionReview._();
  static String describe(EdgeEntryPreview preview){
    final b=StringBuffer();
    b.writeln('CUTTING V2 MOTION REVIEW - NOT G-CODE');
    b.writeln('EDGE START X=${preview.start.x.toStringAsFixed(3)} Y=${preview.start.y.toStringAsFixed(3)}');
    b.writeln('ENTRY X=${preview.entry.x.toStringAsFixed(3)} Y=${preview.entry.y.toStringAsFixed(3)}');
    b.writeln('CONTOUR SEGMENTS=${preview.contour.segments.length}');
    for(final warning in preview.warnings){b.writeln('WARNING: $warning');}
    b.writeln('MACHINE EXPORT BLOCKED');
    return b.toString();
  }
}
