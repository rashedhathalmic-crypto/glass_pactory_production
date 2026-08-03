import 'dart:math' as math;

import '../../../core/helpers/pdf_profile_analysis.dart';

/// Applies editable corner angles and chamfer values to a scaled profile.
///
/// A degree value placed with a chamfer value is treated as the chamfer angle
/// (for example 15 mm + 45 degrees). A degree value placed on a sharp corner
/// without a chamfer remains an editable interior corner angle.
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
    final features = _detectFeatures(profile);
    if (features.isEmpty) return profile;

    final requests = <int, _FeatureRequest>{};
    for (var index = 0; index < count; index++) {
      final reading = readings[index];
      final value = values[index];
      if (value == null || !value.isFinite) continue;
      if (!reading.isAngle && !reading.isChamfer) continue;
      if (reading.isAngle && (value <= 0.1 || value >= 179.9)) continue;
      if (reading.isChamfer && value <= 0) continue;

      final feature = _nearestFeature(profile, features, reading);
      final request = requests.putIfAbsent(
        feature.id,
        () => _FeatureRequest(feature),
      );
      if (reading.isAngle) {
        request.angleDegrees = value;
      } else {
        request.chamfer = value;
      }
    }

    if (requests.isEmpty) return profile;

    // A standalone angle on a sharp corner remains an interior-angle edit.
    for (final request in requests.values) {
      final vertexIndex = request.feature.vertexIndex;
      if (vertexIndex == null || request.chamfer != null) continue;
      final angle = request.angleDegrees;
      if (angle == null) continue;
      _setInteriorAngle(points, vertexIndex, angle);
    }

    // Existing chamfer edges are resized/re-angled in place. This prevents an
    // already chamfered image contour from being chamfered a second time.
    for (final request in requests.values) {
      if (!request.feature.isExistingChamfer) continue;
      _applyExistingChamfer(
        points,
        request.feature,
        chamfer: request.chamfer,
        angleDegrees: request.angleDegrees,
      );
    }

    // Sharp corners receiving a chamfer are replaced by exactly two endpoints.
    final replacements = <int, List<PdfProfilePoint>>{};
    for (final request in requests.values) {
      final vertexIndex = request.feature.vertexIndex;
      final chamfer = request.chamfer;
      if (vertexIndex == null || chamfer == null) continue;
      final pair = _buildSharpChamfer(
        points,
        vertexIndex,
        chamfer: chamfer,
        angleDegrees: request.angleDegrees,
      );
      if (pair != null) replacements[vertexIndex] = pair;
    }

    final featured = <PdfProfilePoint>[];
    for (var index = 0; index < points.length; index++) {
      final replacement = replacements[index];
      if (replacement == null) {
        featured.add(points[index]);
      } else {
        featured.addAll(replacement);
      }
    }
    return _normalizedCandidate(profile, featured);
  }

  static List<_CornerFeature> _detectFeatures(PdfProfileCandidate profile) {
    final points = profile.points;
    final count = points.length;
    final features = <_CornerFeature>[];
    final existingEndpoints = <int>{};
    var nextId = 0;

    for (var index = 0; index < count; index++) {
      final endIndex = (index + 1) % count;
      if (existingEndpoints.contains(index) ||
          existingEndpoints.contains(endIndex)) {
        continue;
      }
      final previousIndex = (index - 1 + count) % count;
      final nextIndex = (endIndex + 1) % count;
      final previous = points[previousIndex];
      final start = points[index];
      final end = points[endIndex];
      final next = points[nextIndex];
      final edgeLength = _distance(start, end);
      final previousLength = _distance(previous, start);
      final nextLength = _distance(end, next);
      if (edgeLength <= 1e-8 ||
          previousLength <= 1e-8 ||
          nextLength <= 1e-8 ||
          edgeLength >= math.min(previousLength, nextLength) * 0.72) {
        continue;
      }

      final corner = _lineIntersection(previous, start, end, next);
      if (corner == null) continue;
      final firstSetback = _distance(corner, start);
      final secondSetback = _distance(corner, end);
      if (firstSetback <= 1e-8 ||
          secondSetback <= 1e-8 ||
          firstSetback >= previousLength * 0.8 ||
          secondSetback >= nextLength * 0.8) {
        continue;
      }

      final previousDirection = _vector(previous, start);
      final firstExtension = _vector(start, corner);
      final nextDirection = _vector(end, next);
      final secondExtension = _vector(end, corner);
      if (_dot(previousDirection, firstExtension) <= 0 ||
          _dot(nextDirection, secondExtension) >= 0) {
        continue;
      }

      features.add(
        _CornerFeature.existingChamfer(
          id: nextId++,
          edgeStartIndex: index,
          edgeEndIndex: endIndex,
        ),
      );
      existingEndpoints
        ..add(index)
        ..add(endIndex);
    }

    for (var index = 0; index < count; index++) {
      if (existingEndpoints.contains(index)) continue;
      features.add(
        _CornerFeature.sharp(id: nextId++, vertexIndex: index),
      );
    }
    return features;
  }

  static _CornerFeature _nearestFeature(
    PdfProfileCandidate profile,
    List<_CornerFeature> features,
    ImageDimensionReading reading,
  ) {
    var nearest = features.first;
    var bestDistance = double.infinity;
    for (final feature in features) {
      final distance = _featureDistance(profile, feature, reading);
      if (distance < bestDistance) {
        nearest = feature;
        bestDistance = distance;
      }
    }
    return nearest;
  }

  static double _featureDistance(
    PdfProfileCandidate profile,
    _CornerFeature feature,
    ImageDimensionReading reading,
  ) {
    final points = profile.points;
    final anchors = <PdfProfilePoint>[];
    final vertexIndex = feature.vertexIndex;
    if (vertexIndex != null) {
      anchors.add(points[vertexIndex]);
    } else {
      final startIndex = feature.edgeStartIndex!;
      final endIndex = feature.edgeEndIndex!;
      final start = points[startIndex];
      final end = points[endIndex];
      anchors.add(
        PdfProfilePoint((start.x + end.x) / 2, (start.y + end.y) / 2),
      );
      final previous = points[(startIndex - 1 + points.length) % points.length];
      final next = points[(endIndex + 1) % points.length];
      final corner = _lineIntersection(previous, start, end, next);
      if (corner != null) anchors.add(corner);
    }

    final safeWidth = math.max(profile.width, 1e-9);
    final safeHeight = math.max(profile.height, 1e-9);
    var best = double.infinity;
    for (final anchor in anchors) {
      final normalizedX = anchor.x / safeWidth;
      final normalizedY = 1 - anchor.y / safeHeight;
      final distance = _hypot(
        normalizedX - reading.x,
        normalizedY - reading.y,
      );
      if (distance < best) best = distance;
    }
    // Prefer an existing chamfer edge over one of its nearby visual corners.
    return feature.isExistingChamfer ? best * 0.92 : best;
  }

  static void _applyExistingChamfer(
    List<PdfProfilePoint> points,
    _CornerFeature feature, {
    required double? chamfer,
    required double? angleDegrees,
  }) {
    final startIndex = feature.edgeStartIndex!;
    final endIndex = feature.edgeEndIndex!;
    final previousIndex = (startIndex - 1 + points.length) % points.length;
    final nextIndex = (endIndex + 1) % points.length;
    final previous = points[previousIndex];
    final start = points[startIndex];
    final end = points[endIndex];
    final next = points[nextIndex];
    final corner = _lineIntersection(previous, start, end, next);
    if (corner == null) return;

    final firstRay = _unitVector(corner, start);
    final secondRay = _unitVector(corner, end);
    if (firstRay == null || secondRay == null) return;
    final cornerAngle = _angleBetween(firstRay, secondRay);
    final existingFirstSetback = _distance(corner, start);
    final existingAngle = _angleBetween(
      _vector(start, corner),
      _vector(start, end),
    );
    final chamferAngle = _resolveChamferAngle(
      angleDegrees,
      cornerAngle,
      fallback: existingAngle,
    );
    if (chamferAngle == null) return;

    var firstSetback = chamfer ?? existingFirstSetback;
    var secondSetback = _secondSetback(
      firstSetback,
      cornerAngle,
      chamferAngle,
    );
    if (secondSetback == null) return;

    final maximumFirst = _distance(corner, previous) * 0.45;
    final maximumSecond = _distance(corner, next) * 0.45;
    final scale = math.min(
      1.0,
      math.min(
        maximumFirst / math.max(firstSetback, 1e-9),
        maximumSecond / math.max(secondSetback, 1e-9),
      ),
    );
    firstSetback *= scale;
    secondSetback *= scale;

    points[startIndex] = PdfProfilePoint(
      corner.x + firstRay.$1 * firstSetback,
      corner.y + firstRay.$2 * firstSetback,
    );
    points[endIndex] = PdfProfilePoint(
      corner.x + secondRay.$1 * secondSetback,
      corner.y + secondRay.$2 * secondSetback,
    );
  }

  static List<PdfProfilePoint>? _buildSharpChamfer(
    List<PdfProfilePoint> points,
    int index, {
    required double chamfer,
    required double? angleDegrees,
  }) {
    if (points.length < 3 || index < 0 || index >= points.length) return null;
    final previous = points[(index - 1 + points.length) % points.length];
    final corner = points[index];
    final next = points[(index + 1) % points.length];
    final firstRay = _unitVector(corner, previous);
    final secondRay = _unitVector(corner, next);
    if (firstRay == null || secondRay == null) return null;
    final cornerAngle = _angleBetween(firstRay, secondRay);
    final chamferAngle = _resolveChamferAngle(
      angleDegrees,
      cornerAngle,
      fallback: (math.pi - cornerAngle) / 2,
    );
    if (chamferAngle == null) return null;

    var firstSetback = chamfer;
    var secondSetback = _secondSetback(
      firstSetback,
      cornerAngle,
      chamferAngle,
    );
    if (secondSetback == null) return null;

    final maximumFirst = _distance(corner, previous) * 0.45;
    final maximumSecond = _distance(corner, next) * 0.45;
    final scale = math.min(
      1.0,
      math.min(
        maximumFirst / math.max(firstSetback, 1e-9),
        maximumSecond / math.max(secondSetback, 1e-9),
      ),
    );
    firstSetback *= scale;
    secondSetback *= scale;

    return [
      PdfProfilePoint(
        corner.x + firstRay.$1 * firstSetback,
        corner.y + firstRay.$2 * firstSetback,
      ),
      PdfProfilePoint(
        corner.x + secondRay.$1 * secondSetback,
        corner.y + secondRay.$2 * secondSetback,
      ),
    ];
  }

  static double? _resolveChamferAngle(
    double? requestedDegrees,
    double cornerAngle, {
    required double fallback,
  }) {
    final maximum = math.pi - cornerAngle;
    if (!maximum.isFinite || maximum <= 1e-5) return null;
    var candidate = fallback;
    if (requestedDegrees != null && requestedDegrees.isFinite) {
      var degrees = requestedDegrees;
      // Accept the old interior-angle notation too: 135 becomes 45.
      if (degrees >= 90 && degrees < 180) degrees = 180 - degrees;
      candidate = degrees * math.pi / 180;
    }
    if (!candidate.isFinite || candidate <= 1e-5 || candidate >= maximum) {
      candidate = maximum / 2;
    }
    return candidate.clamp(1e-5, maximum - 1e-5).toDouble();
  }

  static double? _secondSetback(
    double firstSetback,
    double cornerAngle,
    double chamferAngle,
  ) {
    final denominator = math.sin(cornerAngle + chamferAngle);
    if (firstSetback <= 0 || denominator.abs() <= 1e-9) return null;
    final value = firstSetback * math.sin(chamferAngle) / denominator;
    return value.isFinite && value > 0 ? value : null;
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

  static PdfProfilePoint? _lineIntersection(
    PdfProfilePoint firstStart,
    PdfProfilePoint firstEnd,
    PdfProfilePoint secondStart,
    PdfProfilePoint secondEnd,
  ) {
    final firstX = firstEnd.x - firstStart.x;
    final firstY = firstEnd.y - firstStart.y;
    final secondX = secondEnd.x - secondStart.x;
    final secondY = secondEnd.y - secondStart.y;
    final cross = firstX * secondY - firstY * secondX;
    if (cross.abs() <= 1e-9) return null;
    final offsetX = secondStart.x - firstStart.x;
    final offsetY = secondStart.y - firstStart.y;
    final t = (offsetX * secondY - offsetY * secondX) / cross;
    return PdfProfilePoint(
      firstStart.x + firstX * t,
      firstStart.y + firstY * t,
    );
  }

  static (double, double)? _unitVector(
    PdfProfilePoint start,
    PdfProfilePoint end,
  ) {
    final x = end.x - start.x;
    final y = end.y - start.y;
    final length = _hypot(x, y);
    if (length <= 1e-9) return null;
    return (x / length, y / length);
  }

  static (double, double) _vector(
    PdfProfilePoint start,
    PdfProfilePoint end,
  ) =>
      (end.x - start.x, end.y - start.y);

  static double _angleBetween(
    (double, double) first,
    (double, double) second,
  ) {
    final denominator = _hypot(first.$1, first.$2) *
        _hypot(second.$1, second.$2);
    if (denominator <= 1e-12) return 0;
    final cosine = (_dot(first, second) / denominator)
        .clamp(-1.0, 1.0)
        .toDouble();
    return math.acos(cosine);
  }

  static double _dot(
    (double, double) first,
    (double, double) second,
  ) =>
      first.$1 * second.$1 + first.$2 * second.$2;

  static double _distance(PdfProfilePoint first, PdfProfilePoint second) {
    return _hypot(second.x - first.x, second.y - first.y);
  }

  static double _hypot(double x, double y) => math.sqrt(x * x + y * y);
}

class _CornerFeature {
  const _CornerFeature._({
    required this.id,
    this.vertexIndex,
    this.edgeStartIndex,
    this.edgeEndIndex,
  });

  const _CornerFeature.sharp({
    required int id,
    required int vertexIndex,
  }) : this._(id: id, vertexIndex: vertexIndex);

  const _CornerFeature.existingChamfer({
    required int id,
    required int edgeStartIndex,
    required int edgeEndIndex,
  }) : this._(
          id: id,
          edgeStartIndex: edgeStartIndex,
          edgeEndIndex: edgeEndIndex,
        );

  final int id;
  final int? vertexIndex;
  final int? edgeStartIndex;
  final int? edgeEndIndex;

  bool get isExistingChamfer => edgeStartIndex != null;
}

class _FeatureRequest {
  _FeatureRequest(this.feature);

  final _CornerFeature feature;
  double? angleDegrees;
  double? chamfer;
}
