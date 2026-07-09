import 'dart:math' as math;

class PolygonAreaHelper {
  PolygonAreaHelper._();

  /// Calculates the area of a regular polygon from side count and side lengths (mm).
  /// Uses the average side length when lengths differ slightly.
  static double calculateAreaSqM({
    required int sides,
    required List<double> sideLengthsMm,
  }) {
    if (sides < 3 || sideLengthsMm.isEmpty) return 0;

    final validLengths = sideLengthsMm.where((length) => length > 0).toList();
    if (validLengths.isEmpty) return 0;

    final averageSide =
        validLengths.reduce((a, b) => a + b) / validLengths.length;
    final areaMm2 =
        (sides * averageSide * averageSide) / (4 * math.tan(math.pi / sides));
    return areaMm2 / 1000000;
  }
}
