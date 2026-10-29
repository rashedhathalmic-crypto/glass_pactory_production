import 'package:flutter_test/flutter_test.dart';
import 'package:glass_pactory_production/features/nc_generator/domain/cam_engine.dart';
import 'package:glass_pactory_production/features/nc_generator/domain/dxf_document.dart';
import 'package:glass_pactory_production/features/nc_generator/domain/glass_edge_entry_planner.dart';

void main() {
  final square = CamContour(
    segments: const [
      CamLine(DxfPoint(20,20),DxfPoint(40,20)),
      CamLine(DxfPoint(40,20),DxfPoint(40,40)),
      CamLine(DxfPoint(40,40),DxfPoint(20,40)),
      CamLine(DxfPoint(20,40),DxfPoint(20,20)),
    ],
    closed:true,signedArea:400,kind:ContourKind.external,depth:0);
  test('edge entry begins outside stock', () {
    final route=GlassEdgeEntryPlanner.preview(
        square,const GlassStock(0,0,100,100));
    expect(route.start.x<0 || route.start.y<0 ||
        route.start.x>100 || route.start.y>100,isTrue);
    expect(route.warnings,isNotEmpty);
    expect(CuttingMotionReview.describe(route),contains('NOT G-CODE'));
  });
  test('invalid stock rejected', () {
    expect(()=>GlassEdgeEntryPlanner.preview(
        square,const GlassStock(0,0,0,100)),throwsArgumentError);
  });
}
