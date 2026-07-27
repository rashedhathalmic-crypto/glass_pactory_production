import 'package:flutter_test/flutter_test.dart';
import 'package:glass_pactory_production/features/nc_generator/domain/dxf_document.dart';
import 'package:glass_pactory_production/features/nc_generator/domain/dxf_parser.dart';
import 'package:glass_pactory_production/features/nc_generator/domain/nc_generator.dart';

void main() {
  const dxf = '''0
SECTION
2
ENTITIES
0
LINE
10
0
20
0
11
100
21
50
0
ARC
10
50
20
50
40
20
50
0
51
90
0
CIRCLE
10
25
20
25
40
10
0
LWPOLYLINE
70
1
10
0
20
0
10
20
20
0
10
20
20
20
0
POLYLINE
70
1
0
VERTEX
10
5
20
5
0
VERTEX
10
10
20
10
0
SEQEND
0
ENDSEC
0
EOF
''';

  test('parses every supported DXF entity', () {
    final document = DxfParser.parse(dxf);
    expect(document.entities, hasLength(5));
    expect(document.entities.map((e) => e.runtimeType), [DxfLine, DxfArc, DxfCircle, DxfPolyline, DxfPolyline]);
    expect((document.entities[3] as DxfPolyline).closed, isTrue);
  });

  test('generates NC from imported geometry and settings', () {
    const closedDxf = '''0
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
    final output = NcGenerator.generate(DxfParser.parse(closedDxf), const NcParameters(drawingName: 'part.dxf', toolNumber: 3, xOffset: 2, yOffset: -1, cuttingFeed: 900, maxPassDepth: 5));
    expect(output, contains('(DXF:PART.DXF UNITS:UNITLESS THK:19MM)'));
    expect(output, contains('T3 M06'));
    expect(output, contains('PASS 4/4 Z-19'));
    expect(output, contains('G03'));
    expect(output, endsWith('M30\n%\n'));
  });

  test('blocks NC generation when a contour is open', () {
    expect(
      () => NcGenerator.generate(
        const DxfDocument([DxfLine(DxfPoint(0, 0), DxfPoint(10, 0))]),
        const NcParameters(drawingName: 'open.dxf'),
      ),
      throwsArgumentError,
    );
  });

  test('rejects a DXF without supported entities', () {
    expect(() => DxfParser.parse('0\nSECTION\n2\nENTITIES\n0\nENDSEC\n0\nEOF\n'), throwsFormatException);
  });
}
