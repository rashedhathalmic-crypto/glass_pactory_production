import 'package:flutter_test/flutter_test.dart';
import 'package:glass_pactory_production/features/nc_generator/domain/drawing_analyzer.dart';
import 'package:glass_pactory_production/features/nc_generator/domain/dxf_document.dart';
import 'package:glass_pactory_production/features/nc_generator/domain/dxf_parser.dart';
import 'package:glass_pactory_production/features/nc_generator/domain/nc_generator.dart';

void main() {
  const dxf = '''0
SECTION
2
ENTITIES
0
LWPOLYLINE
70
1
10
0
20
0
10
100
20
0
10
100
20
50
10
0
20
50
0
CIRCLE
10
25
20
25
40
5
0
ENDSEC
0
EOF
''';
  test('parses and classifies perimeter and circular hole in machining order', () {
    final analysis = DrawingAnalyzer.analyze(DxfParser.parse(dxf));
    expect(analysis.width, 100);
    expect(analysis.height, 50);
    expect(analysis.contours.map((c) => c.kind), [ContourKind.circularHole, ContourKind.externalPerimeter]);
  });
  test('preserves polyline bulges as arc segments', () {
    const source = '0\nSECTION\n2\nENTITIES\n0\nLWPOLYLINE\n70\n0\n10\n0\n20\n0\n42\n1\n10\n10\n20\n0\n0\nENDSEC\n0\nEOF\n';
    expect(DrawingAnalyzer.analyze(DxfParser.parse(source)).contours.single.segments.single, isA<ArcSegment>());
  });
  test('generates arcs, IJ centers and progressive passes', () {
    final result = NcGenerator.generateProgram(DxfParser.parse(dxf), const NcParameters(drawingName: 'panel.dxf', finalDepth: -5, depthPerPass: 2, toolDiameter: 2));
    expect(result.text, contains('(DXF: PANEL.DXF)'));
    expect(result.text, contains('G90 G17 G21 G40 G49 G80'));
    expect(result.text, contains('G03 X'));
    expect(result.text, contains(' I-'));
    expect(result.text, contains('G01 Z-2.000'));
    expect(result.text, contains('G01 Z-4.000'));
    expect(result.text, contains('G01 Z-5.000'));
    expect(result.text, endsWith('M30\n%\n'));
    expect(result.motions, isNotEmpty);
  });
  test('never rapids XY below safe Z', () {
    final result = NcGenerator.generateProgram(DxfParser.parse(dxf), const NcParameters(drawingName: 'safe.dxf', finalDepth: -2, depthPerPass: 1, toolDiameter: 2));
    for (final move in result.motions.where((m) => m.type == MotionType.rapid && (m.start.x != m.end.x || m.start.y != m.end.y))) {
      expect(move.start.z, 20);
      expect(move.end.z, 20);
    }
  });
  test('rejects unsupported-only DXF', () => expect(() => DxfParser.parse('0\nSECTION\n2\nENTITIES\n0\nENDSEC\n0\nEOF\n'), throwsFormatException));
}
