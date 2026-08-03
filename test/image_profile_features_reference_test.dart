import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_pactory_production/core/helpers/pdf_profile_analysis.dart';
import 'package:glass_pactory_production/features/nc_generator/domain/image_profile_features.dart';

void main() {
  const referencePoints = <PdfProfilePoint>[
    PdfProfilePoint(209, 179),
    PdfProfilePoint(15, 179),
    PdfProfilePoint(0, 164),
    PdfProfilePoint(0, 15),
    PdfProfilePoint(15, 0),
    PdfProfilePoint(209, 0),
    PdfProfilePoint(224, 15),
    PdfProfilePoint(224, 164),
  ];

  test('creates the original 1039 MNG outline from C15 and 45 degrees', () {
    const rectangle = PdfProfileCandidate(
      id: 1,
      suggested: true,
      inferredClosure: false,
      vertexCount: 4,
      width: 224,
      height: 179,
      points: <PdfProfilePoint>[
        PdfProfilePoint(0, 0),
        PdfProfilePoint(224, 0),
        PdfProfilePoint(224, 179),
        PdfProfilePoint(0, 179),
      ],
    );
    final readings = <ImageDimensionReading>[];
    final values = <double?>[];
    for (final corner in rectangle.points) {
      final x = corner.x / rectangle.width;
      final y = 1 - corner.y / rectangle.height;
      readings
        ..add(
          ImageDimensionReading(
            value: '15',
            confidence: 100,
            x: x,
            y: y,
            vertical: false,
            kind: ImageGeometryValueKind.chamfer,
          ),
        )
        ..add(
          ImageDimensionReading(
            value: '45',
            confidence: 100,
            x: x,
            y: y,
            vertical: false,
            kind: ImageGeometryValueKind.angle,
          ),
        );
      values
        ..add(15)
        ..add(45);
    }

    final result = ImageProfileFeatures.apply(
      profile: rectangle,
      readings: readings,
      values: values,
    );

    expect(result.vertexCount, 8);
    expect(result.width, closeTo(224, 1e-6));
    expect(result.height, closeTo(179, 1e-6));
    expect(_canonical(result.points), _canonical(referencePoints));
    for (var index = 0; index < result.points.length; index++) {
      expect(_interiorAngle(result.points, index), closeTo(135, 1e-6));
    }
  });

  test('does not double-chamfer the already chamfered original outline', () {
    const original = PdfProfileCandidate(
      id: 1039,
      suggested: true,
      inferredClosure: false,
      vertexCount: 8,
      width: 224,
      height: 179,
      points: referencePoints,
    );
    const virtualCorners = <PdfProfilePoint>[
      PdfProfilePoint(0, 179),
      PdfProfilePoint(0, 0),
      PdfProfilePoint(224, 0),
      PdfProfilePoint(224, 179),
    ];
    final readings = <ImageDimensionReading>[];
    final values = <double?>[];
    for (final corner in virtualCorners) {
      final x = corner.x / original.width;
      final y = 1 - corner.y / original.height;
      readings
        ..add(
          ImageDimensionReading(
            value: '15',
            confidence: 100,
            x: x,
            y: y,
            vertical: false,
            kind: ImageGeometryValueKind.chamfer,
          ),
        )
        ..add(
          ImageDimensionReading(
            value: '45',
            confidence: 100,
            x: x,
            y: y,
            vertical: false,
            kind: ImageGeometryValueKind.angle,
          ),
        );
      values
        ..add(15)
        ..add(45);
    }

    final result = ImageProfileFeatures.apply(
      profile: original,
      readings: readings,
      values: values,
    );

    expect(result.vertexCount, 8);
    expect(_canonical(result.points), _canonical(referencePoints));
  });
}

List<String> _canonical(List<PdfProfilePoint> points) {
  final values = points
      .map(
        (point) =>
            '${point.x.toStringAsFixed(6)},${point.y.toStringAsFixed(6)}',
      )
      .toList(growable: false)
    ..sort();
  return values;
}

double _interiorAngle(List<PdfProfilePoint> points, int index) {
  final previous = points[(index - 1 + points.length) % points.length];
  final current = points[index];
  final next = points[(index + 1) % points.length];
  final firstX = previous.x - current.x;
  final firstY = previous.y - current.y;
  final secondX = next.x - current.x;
  final secondY = next.y - current.y;
  final denominator = math.sqrt(firstX * firstX + firstY * firstY) *
      math.sqrt(secondX * secondX + secondY * secondY);
  final cosine = ((firstX * secondX + firstY * secondY) / denominator)
      .clamp(-1.0, 1.0)
      .toDouble();
  return math.acos(cosine) * 180 / math.pi;
}
