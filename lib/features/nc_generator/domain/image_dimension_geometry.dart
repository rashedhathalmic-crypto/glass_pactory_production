import 'dart:math' as math;

import '../../../core/helpers/pdf_profile_analysis.dart';

/// Rebuilds a raster-detected polygon from editable written dimensions.
///
/// Written horizontal dimensions constrain differences between X coordinate
/// levels, while vertical dimensions constrain Y coordinate levels. All
/// detected values participate in a weighted least-squares solution, so this
/// is not tied to a particular vertex count or drawing shape.
class ImageDimensionGeometry {
  const ImageDimensionGeometry._();

  static PdfProfileCandidate? rebuild({
    required PdfProfileCandidate base,
    required List<ImageDimensionReading> readings,
    required List<double?> values,
  }) {
    if (base.points.length < 3 || base.width <= 0 || base.height <= 0) {
      return null;
    }

    final count = math.min(readings.length, values.length);
    final horizontalInputs = <_ReadingInput>[];
    final verticalInputs = <_ReadingInput>[];
    for (var index = 0; index < count; index++) {
      final value = values[index];
      if (value == null || !value.isFinite || value <= 0) continue;
      final input = _ReadingInput(readings[index], value);
      if (readings[index].vertical) {
        verticalInputs.add(input);
      } else {
        horizontalInputs.add(input);
      }
    }
    if (horizontalInputs.isEmpty && verticalInputs.isEmpty) return null;

    final xModel = _AxisModel.fromProfile(base, horizontal: true);
    final yModel = _AxisModel.fromProfile(base, horizontal: false);
    final xConstraints = xModel.match(horizontalInputs);
    final yConstraints = yModel.match(verticalInputs);

    var xScale = _medianPositive(
      xConstraints.map((constraint) => constraint.ratio),
    );
    var yScale = _medianPositive(
      yConstraints.map((constraint) => constraint.ratio),
    );
    if (xScale == null && yScale == null) return null;
    xScale ??= yScale;
    yScale ??= xScale;

    final solvedX = xModel.solve(xConstraints, fallbackScale: xScale!);
    final solvedY = yModel.solve(yConstraints, fallbackScale: yScale!);
    if (solvedX.length != xModel.levels.length ||
        solvedY.length != yModel.levels.length) {
      return null;
    }

    final points = base.points
        .map(
          (point) => PdfProfilePoint(
            xModel.mapCoordinate(point.x, solvedX),
            yModel.mapCoordinate(point.y, solvedY),
          ),
        )
        .toList(growable: false);
    final minX = points.map((point) => point.x).reduce(math.min);
    final minY = points.map((point) => point.y).reduce(math.min);
    final normalized = points
        .map((point) => PdfProfilePoint(point.x - minX, point.y - minY))
        .toList(growable: false);
    final width = normalized.map((point) => point.x).reduce(math.max);
    final height = normalized.map((point) => point.y).reduce(math.max);
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      return null;
    }

    return PdfProfileCandidate(
      id: base.id,
      suggested: true,
      inferredClosure: base.inferredClosure,
      vertexCount: normalized.length,
      width: width,
      height: height,
      points: normalized,
    );
  }

  static double? _medianPositive(Iterable<double> values) {
    final sorted = values
        .where((value) => value.isFinite && value > 0)
        .toList(growable: false)
      ..sort();
    if (sorted.isEmpty) return null;
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }
}

class _ReadingInput {
  const _ReadingInput(this.reading, this.value);

  final ImageDimensionReading reading;
  final double value;
}

class _PairOption {
  const _PairOption({
    required this.a,
    required this.b,
    required this.span,
    required this.geometryScore,
  });

  final int a;
  final int b;
  final double span;
  final double geometryScore;
}

class _AxisConstraint {
  const _AxisConstraint({
    required this.a,
    required this.b,
    required this.value,
    required this.ratio,
    required this.score,
    required this.confidence,
  });

  final int a;
  final int b;
  final double value;
  final double ratio;
  final double score;
  final double confidence;
}

class _AxisModel {
  _AxisModel({
    required this.horizontal,
    required this.levels,
    required this.pointLevelIndices,
    required this.crossValuesByLevel,
    required this.extent,
    required this.crossExtent,
  });

  factory _AxisModel.fromProfile(
    PdfProfileCandidate profile, {
    required bool horizontal,
  }) {
    final axisValues = profile.points
        .map((point) => horizontal ? point.x : point.y)
        .toList(growable: false);
    final crossValues = profile.points
        .map((point) => horizontal ? point.y : point.x)
        .toList(growable: false);
    final extent = horizontal ? profile.width : profile.height;
    final crossExtent = horizontal ? profile.height : profile.width;
    final tolerance = math.max(0.05, extent * 0.004);
    final sorted = axisValues.toList(growable: true)..sort();
    final levels = <double>[];
    for (final value in sorted) {
      if (levels.isEmpty || (value - levels.last).abs() > tolerance) {
        levels.add(value);
      } else {
        levels[levels.length - 1] = (levels.last + value) / 2;
      }
    }
    if (levels.length < 2) {
      levels
        ..clear()
        ..addAll([0, extent]);
    }

    int nearestLevel(double value) {
      var best = 0;
      var bestDistance = double.infinity;
      for (var index = 0; index < levels.length; index++) {
        final distance = (levels[index] - value).abs();
        if (distance < bestDistance) {
          best = index;
          bestDistance = distance;
        }
      }
      return best;
    }

    final pointLevelIndices = axisValues.map(nearestLevel).toList();
    final crossValuesByLevel = List<List<double>>.generate(
      levels.length,
      (_) => <double>[],
    );
    for (var index = 0; index < pointLevelIndices.length; index++) {
      crossValuesByLevel[pointLevelIndices[index]].add(crossValues[index]);
    }

    return _AxisModel(
      horizontal: horizontal,
      levels: levels,
      pointLevelIndices: pointLevelIndices,
      crossValuesByLevel: crossValuesByLevel,
      extent: extent,
      crossExtent: crossExtent,
    );
  }

  final bool horizontal;
  final List<double> levels;
  final List<int> pointLevelIndices;
  final List<List<double>> crossValuesByLevel;
  final double extent;
  final double crossExtent;

  List<_AxisConstraint> match(List<_ReadingInput> inputs) {
    if (inputs.isEmpty || levels.length < 2) return const [];
    final optionSets = inputs.map(_optionsFor).toList(growable: false);
    if (optionSets.any((options) => options.isEmpty)) return const [];

    var chosen = optionSets.map((options) => options.first).toList();
    for (var iteration = 0; iteration < 4; iteration++) {
      final ratios = <double>[];
      for (var index = 0; index < inputs.length; index++) {
        ratios.add(inputs[index].value / chosen[index].span);
      }
      final scale = ImageDimensionGeometry._medianPositive(ratios) ?? 1;
      chosen = List<_PairOption>.generate(inputs.length, (index) {
        final input = inputs[index];
        return optionSets[index].reduce((best, option) {
          final bestScore = _combinedScore(best, input.value, scale);
          final optionScore = _combinedScore(option, input.value, scale);
          return optionScore < bestScore ? option : best;
        });
      });
    }

    return List<_AxisConstraint>.generate(inputs.length, (index) {
      final input = inputs[index];
      final option = chosen[index];
      return _AxisConstraint(
        a: option.a,
        b: option.b,
        value: input.value,
        ratio: input.value / option.span,
        score: option.geometryScore,
        confidence: input.reading.confidence.clamp(0, 100).toDouble() / 100,
      );
    });
  }

  double _combinedScore(_PairOption option, double value, double scale) {
    final ratio = value / option.span;
    final scalePenalty = (math.log(ratio / scale)).abs();
    return option.geometryScore + scalePenalty * 0.9;
  }

  List<_PairOption> _optionsFor(_ReadingInput input) {
    final reading = input.reading;
    final labelAxis = horizontal ? reading.x : 1 - reading.y;
    final labelCross = horizontal ? 1 - reading.y : reading.x;
    final options = <_PairOption>[];
    final safeExtent = math.max(extent, 1e-9);
    final safeCross = math.max(crossExtent, 1e-9);

    for (var a = 0; a < levels.length - 1; a++) {
      for (var b = a + 1; b < levels.length; b++) {
        final span = levels[b] - levels[a];
        if (span <= safeExtent * 0.015) continue;
        final low = levels[a] / safeExtent;
        final high = levels[b] / safeExtent;
        final midpoint = (low + high) / 2;
        final midpointDistance = (midpoint - labelAxis).abs();
        final outsideDistance = labelAxis < low
            ? low - labelAxis
            : labelAxis > high
                ? labelAxis - high
                : 0.0;
        final crossDistance = _crossDistance(a, b, labelCross * safeCross) /
            safeCross;
        final relativeSpan = span / safeExtent;
        final smallSpanPenalty = (1 - relativeSpan) * 0.08;
        final score = midpointDistance * 1.15 +
            outsideDistance * 1.6 +
            crossDistance * 0.32 +
            smallSpanPenalty;
        options.add(
          _PairOption(
            a: a,
            b: b,
            span: span,
            geometryScore: score,
          ),
        );
      }
    }
    options.sort((left, right) =>
        left.geometryScore.compareTo(right.geometryScore));
    return options.take(math.min(10, options.length)).toList(growable: false);
  }

  double _crossDistance(int a, int b, double target) {
    final first = crossValuesByLevel[a];
    final second = crossValuesByLevel[b];
    if (first.isEmpty || second.isEmpty) return crossExtent * 0.5;
    var best = double.infinity;
    for (final left in first) {
      for (final right in second) {
        final distance = ((left + right) / 2 - target).abs();
        if (distance < best) best = distance;
      }
    }
    return best;
  }

  List<double> solve(
    List<_AxisConstraint> constraints, {
    required double fallbackScale,
  }) {
    final count = levels.length;
    if (count < 2) return const [];
    final matrix = List<List<double>>.generate(
      count,
      (_) => List<double>.filled(count + 1, 0),
    );

    void addEquation(Map<int, double> coefficients, double rhs, double weight) {
      for (final row in coefficients.entries) {
        for (final column in coefficients.entries) {
          matrix[row.key][column.key] +=
              weight * row.value * column.value;
        }
        matrix[row.key][count] += weight * row.value * rhs;
      }
    }

    addEquation(const {0: 1}, 0, 1000000);
    for (var index = 0; index < count - 1; index++) {
      final expected = (levels[index + 1] - levels[index]) * fallbackScale;
      addEquation({index: -1, index + 1: 1}, expected, 1.5);
    }
    addEquation(
      {0: -1, count - 1: 1},
      extent * fallbackScale,
      3,
    );
    for (final constraint in constraints) {
      final confidence = math.max(0.35, constraint.confidence);
      final weight = 240 * confidence / (1 + constraint.score * 5);
      addEquation(
        {constraint.a: -1, constraint.b: 1},
        constraint.value,
        weight,
      );
    }

    final solved = _gaussianSolve(matrix);
    if (solved == null || !_strictlyIncreasing(solved)) {
      return levels.map((level) => level * fallbackScale).toList();
    }
    final origin = solved.first;
    return solved.map((value) => value - origin).toList(growable: false);
  }

  double mapCoordinate(double coordinate, List<double> solved) {
    if (levels.length == 1) return solved.first;
    if (coordinate <= levels.first) return solved.first;
    if (coordinate >= levels.last) return solved.last;
    for (var index = 0; index < levels.length - 1; index++) {
      final left = levels[index];
      final right = levels[index + 1];
      if (coordinate < left || coordinate > right) continue;
      final span = right - left;
      if (span <= 1e-9) return solved[index];
      final t = (coordinate - left) / span;
      return solved[index] + (solved[index + 1] - solved[index]) * t;
    }
    return coordinate * (solved.last / math.max(levels.last, 1e-9));
  }

  static List<double>? _gaussianSolve(List<List<double>> source) {
    final size = source.length;
    final matrix = source.map((row) => row.toList()).toList();
    for (var pivot = 0; pivot < size; pivot++) {
      var best = pivot;
      for (var row = pivot + 1; row < size; row++) {
        if (matrix[row][pivot].abs() > matrix[best][pivot].abs()) best = row;
      }
      if (matrix[best][pivot].abs() < 1e-10) return null;
      if (best != pivot) {
        final temporary = matrix[pivot];
        matrix[pivot] = matrix[best];
        matrix[best] = temporary;
      }
      final divisor = matrix[pivot][pivot];
      for (var column = pivot; column <= size; column++) {
        matrix[pivot][column] /= divisor;
      }
      for (var row = 0; row < size; row++) {
        if (row == pivot) continue;
        final factor = matrix[row][pivot];
        if (factor.abs() < 1e-12) continue;
        for (var column = pivot; column <= size; column++) {
          matrix[row][column] -= factor * matrix[pivot][column];
        }
      }
    }
    return List<double>.generate(size, (index) => matrix[index][size]);
  }

  static bool _strictlyIncreasing(List<double> values) {
    if (values.any((value) => !value.isFinite)) return false;
    for (var index = 0; index < values.length - 1; index++) {
      if (values[index + 1] <= values[index] + 1e-6) return false;
    }
    return true;
  }
}