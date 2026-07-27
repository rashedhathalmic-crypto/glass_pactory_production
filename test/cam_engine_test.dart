import 'package:flutter_test/flutter_test.dart';
import 'package:glass_pactory_production/features/nc_generator/domain/cam_engine.dart';
import 'package:glass_pactory_production/features/nc_generator/domain/dxf_document.dart';
import 'package:glass_pactory_production/features/nc_generator/domain/offset_engine.dart';

void main() {
  test('joins unordered edges and classifies nested holes first', () {
    const outer = DxfPolyline([
      DxfPoint(0, 0), DxfPoint(100, 0), DxfPoint(100, 100), DxfPoint(0, 100),
    ], closed: true);
    const hole = DxfCircle(DxfPoint(50, 50), 10);
    final plan = CamEngine.analyze(const DxfDocument([outer, hole]));

    expect(plan.warnings, isEmpty);
    expect(plan.contours, hasLength(2));
    expect(plan.contours.first.kind, ContourKind.hole);
    expect(plan.contours.last.kind, ContourKind.external);
  });

  test('preserves a polyline bulge as a CAM arc', () {
    const polyline = DxfPolyline([
      DxfPoint(0, 0), DxfPoint(10, 0), DxfPoint(0, 0),
    ], closed: true, bulges: [1, 0, 0]);
    final plan = CamEngine.analyze(const DxfDocument([polyline]));
    expect(plan.contours.single.segments.first, isA<CamArc>());
  });

  test('reports disconnected open geometry', () {
    final plan = CamEngine.analyze(const DxfDocument([
      DxfLine(DxfPoint(0, 0), DxfPoint(10, 0)),
      DxfLine(DxfPoint(20, 0), DxfPoint(30, 0)),
    ]));
    expect(plan.warnings, hasLength(2));
  });

  test('offset engine preserves circles and creates parallel polygon offsets', () {
    final plan = CamEngine.analyze(const DxfDocument([
      DxfPolyline([DxfPoint(0, 0), DxfPoint(100, 0), DxfPoint(100, 50), DxfPoint(0, 50)], closed: true),
      DxfCircle(DxfPoint(50, 25), 5),
    ]));
    final circle = OffsetEngine.offset(plan.contours.first, 2);
    final rectangle = OffsetEngine.offset(plan.contours.last, 2);
    expect(circle.segments.single, isA<CamArc>());
    expect((circle.segments.single as CamArc).fullCircle, isTrue);
    expect(rectangle.segments, hasLength(4));
    expect(rectangle.length, greaterThan(plan.contours.last.length));
  });
}
