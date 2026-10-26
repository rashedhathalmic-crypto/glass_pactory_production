import 'package:flutter_test/flutter_test.dart';
import 'package:glass_pactory_production/features/nc_generator/domain/cam_engine.dart';
import 'package:glass_pactory_production/features/nc_generator/domain/dxf_document.dart';
import 'package:glass_pactory_production/features/nc_generator/domain/glass_cutting_planner.dart';

void main() {
  final circle = CamContour(
    segments: [
      const CamArc(DxfPoint(20, 20), DxfPoint(20, 20),
          DxfPoint(10, 20), false, fullCircle: true),
    ],
    closed: true,
    signedArea: 314.159,
    kind: ContourKind.external,
    depth: 0,
  );

  test('8 mm tool outside a retained circular part', () {
    final result = GlassCuttingPlanner.preview(circle, retainInterior: true);
    final arc = result.paths.single.segments.single as CamArc;
    expect(arc.radius, closeTo(14, 1e-6));
    expect(result.requiresReview, isTrue);
  });

  test('8 mm tool inside a circular opening', () {
    final result = GlassCuttingPlanner.preview(circle, retainInterior: false);
    final arc = result.paths.single.segments.single as CamArc;
    expect(arc.radius, closeTo(6, 1e-6));
  });

  test('rejects impossible internal radius', () {
    expect(
      () => GlassCuttingPlanner.preview(
        circle, toolDiameterMm: 22, retainInterior: false),
      throwsArgumentError,
    );
  });

  test('rejects open contours', () {
    final open = CamContour(
      segments: [const CamLine(DxfPoint(0, 0), DxfPoint(10, 0))],
      closed: false,
      signedArea: 0,
      kind: ContourKind.external,
      depth: 0,
    );
    expect(
      () => GlassCuttingPlanner.preview(open, retainInterior: true),
      throwsArgumentError,
    );
  });
}
