import 'dart:math' as math;

import '../../../core/helpers/pdf_profile_analysis.dart';

/// Applies editable angle and chamfer values to a dimension-scaled profile.
///
/// Angles are attached to the nearest detected corner. The selected corner is
/// moved while its two neighbouring corners remain fixed, so the polygon stays
/// closed. Chamfer values are equal setbacks in millimetres along both edges
/// that meet at the selected corner.
class ImageProfileFeatures {
  const ImageProfileFeatures._();

  static PdfProfileCandidate apply({
    required PdfProfileCandidate profile,
    required List<ImageDimensionReading> readings,
    required List<double?> values,
  }) {
    if (profile.points.length < 3) return profile;
    final count = math.min(readings.length, values.length);
    final points = profile.points
        .map((point) => PdfProfilePoint(point.x, point.y))
        .toList(growable: true);

    final angleTargets = <int, double>{};
    final chamferTargets = <int, double>{};
    for (var index = 0; index < count; index++) {
      final reading = readings[index];
      final value = values[index];
      if (value == null || !value.isFinite) continue;
      if (reading.isAngle && value > 0.1 && value < 179.9) {
        angleTargets[_nearestVertex(profile, reading)] = value;
      } else if (reading.isChamfer && value > 0) {
        chamferTargets[_nearestVertex(profile, reading)] = value;
      }
    }

    if (angleTargets.isNotEmpty) {
      for (var pass = 0; pass < 8; pass++) {
        for (final entry in angleTargets.entries) {
          _setInteriorAngle(points, entry.key, entry.value);
        }
      }
    }

    final featured = <PdfProfilePoint>[];
    for (var index = 0; index < points.length; index++) {
      final requested = chamferTargets[index];
      if (requested == null || requested <= 0) {
        featured.add(points[index]);
        continue;
      }
      final previous = points[(index - 1 + points.length) % points.length];
      final current = points[index];
      final next = points[(index + 1) % points.length];
      final previousLength = _distance(previous, current);
      final nextLength = _distance(current, next);
      if (previousLength <= 1e-8 || nextLength <= 1e-8) {
        featured.add(current);
        continue;
      }
      final setback = math.min(
        requested,
        math.min(previousLength * 0.45, nextLength * 0.45),
      );
      featured
        ..add(
          PdfProfilePoint(
            current.x + (previous.x - current.x) * setback / previousLength,
            current.y + (previous.y - current.y) * setback / previousLength,
          ),
        )
        ..add(
          PdfProfilePoint(
            current.x + (next.x - current.x) * setback / nextLength,
            current.y + (next.y - current.y) * setback / nextLength,
          ),
        );
    }

    return _normalizedCandidate(profile, featured);
  }

  static int _nearestVertex(
    PdfProfileCandidate profile,
    ImageDimensionReading reading,
  ) {
    final safeWidth = math.max(profile.width, 1e-9);
    final safeHeight = math.max(profile.height, 1e-9);
    var nearest = 0;
    var bestDistance = double.infinity;
    for (var index = 0; index < profile.points.length; index++) {
      final point = profile.points[index];
      final normalizedX = point.x / safeWidth;
      final normalizedY = 1 - point.y / safeHeight;
      final distance = _hypot(
        normalizedX - reading.x,
        normalizedY - reading.y,
      );
      if (distance < bestDistance) {
        nearest = index;
        bestDistance = distance;
      }
    }
    return nearest;
  }

  static void _setInteriorAngle(
    List<PdfProfilePoint> points,
    int index,
    double degrees,
  ) {
    if (points.length < 3 || index < 0 || index >= points.length) return;
    final previous = points[(index - 1 + points.length) % points.length];
    final current = points[index];
    final next = points[(index + 1) % points.length];
    final chordX = next.x - previous.x;
    final chordY = next.y - previous.y;
    final chord = _hypot(chordX, chordY);
    if (chord <= 1e-8) return;

    final unitX = chordX / chord;
    final unitY = chordY / chord;
    final normalX = -unitY;
    final normalY = unitX;
    final relativeX = current.x - previous.x;
    final relativeY = current.y - previous.y;
    var projection = relativeX * unitX + relativeY * unitY;
    projection = projection.clamp(chord * 0.001, chord * 0.999).toDouble();
    final signedHeight = relativeX * normalX + relativeY * normalY;
    final side = signedHeight < 0 ? -1.0 : 1.0;
    final target = degrees * math.pi / 180;

    double pointAngle(double height) {
      final bx = previous.x + unitX * projection + normalX * side * height;
      final by = previous.y + unitY * projection + normalY * side * height;
      final ax = previous.x - bx;
      final ay = previous.y - by;
      final cx = next.x - bx;
      final cy = next.y - by;
      final denominator = _hypot(ax, ay) * _hypot(cx, cy);
      if (denominator <= 1e-12) return math.pi;
      final cosine = ((ax * cx + ay * cy) / denominator)
          .clamp(-1.0, 1.0)
          .toDouble();
      return math.acos(cosine);
    }

    var low = chord * 1e-7;
    var high = math.max(chord, signedHeight.abs() * 2 + chord * 0.1);
    while (pointAngle(high) > target && high < chord * 100000) {
      high *= 2;
    }
    if (pointAngle(high) > target) return;

    for (var iteration = 0; iteration < 80; iteration++) {
      final middle = (low + high) / 2;
      if (pointAngle(middle) > target) {
        low = middle;
      } else {
        high = middle;
      }
    }
    final height = (low + high) / 2;
    points[index] = PdfProfilePoint(
      previous.x + unitX * projection + normalX * side * height,
      previous.y + unitY * projection + normalY * side * height,
    );
  }

  static PdfProfileCandidate _normalizedCandidate(
    PdfProfileCandidate source,
    List<PdfProfilePoint> points,
  ) {
    if (points.length < 3) return source;
    final minX = points.map((point) => point.x).reduce(math.min);
    final minY = points.map((point) => point.y).reduce(math.min);
    final normalized = points
        .map((point) => PdfProfilePoint(point.x - minX, point.y - minY))
        .toList(growable: false);
    final width = normalized.map((point) => point.x).reduce(math.max);
    final height = normalized.map((point) => point.y).reduce(math.max);
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      return source;
    }
    return PdfProfileCandidate(
      id: source.id,
      suggested: true,
      inferredClosure: source.inferredClosure,
      vertexCount: normalized.length,
      width: width,
      height: height,
      points: normalized,
    );
  }

  static double _distance(PdfProfilePoint first, PdfProfilePoint second) {
    return _hypot(second.x - first.x, second.y - first.y);
  }

  static double _hypot(double x, double y) => math.sqrt(x * x + y * y);
}
