import 'dart:math' as math;

class NcSimulationPoint {
  const NcSimulationPoint(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  static NcSimulationPoint lerp(
    NcSimulationPoint a,
    NcSimulationPoint b,
    double t,
  ) {
    return NcSimulationPoint(
      a.x + (b.x - a.x) * t,
      a.y + (b.y - a.y) * t,
      a.z + (b.z - a.z) * t,
    );
  }
}

enum NcMoveKind { rapid, cutting }

class NcSimulationMove {
  const NcSimulationMove({
    required this.start,
    required this.end,
    required this.kind,
    required this.lineNumber,
    required this.feed,
  });

  final NcSimulationPoint start;
  final NcSimulationPoint end;
  final NcMoveKind kind;
  final int lineNumber;
  final double feed;

  double get planarLength {
    final dx = end.x - start.x;
    final dy = end.y - start.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  double get spatialLength {
    final dx = end.x - start.x;
    final dy = end.y - start.y;
    final dz = end.z - start.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }
}

class NcSimulation {
  NcSimulation({
    required this.moves,
    required this.sourceLineCount,
    required this.warnings,
  }) {
    final points = <NcSimulationPoint>[];
    for (final move in moves) {
      points.add(move.start);
      points.add(move.end);
    }

    if (points.isEmpty) {
      minX = maxX = minY = maxY = minZ = maxZ = 0;
    } else {
      minX = points.map((p) => p.x).reduce(math.min);
      maxX = points.map((p) => p.x).reduce(math.max);
      minY = points.map((p) => p.y).reduce(math.min);
      maxY = points.map((p) => p.y).reduce(math.max);
      minZ = points.map((p) => p.z).reduce(math.min);
      maxZ = points.map((p) => p.z).reduce(math.max);
    }

    cuttingDistance = moves
        .where((move) => move.kind == NcMoveKind.cutting)
        .fold(0, (sum, move) => sum + move.planarLength);
    rapidDistance = moves
        .where((move) => move.kind == NcMoveKind.rapid)
        .fold(0, (sum, move) => sum + move.planarLength);

    estimatedSeconds = moves.fold(0, (sum, move) {
      final feed = move.kind == NcMoveKind.rapid
          ? 6000.0
          : math.max(move.feed, 1);
      return sum + move.spatialLength / feed * 60;
    });

    _weights = moves.map((move) {
      final feed = move.kind == NcMoveKind.rapid
          ? 6000.0
          : math.max(move.feed, 1);
      return math.max(move.spatialLength / feed, 0.000001);
    }).toList(growable: false);
    _totalWeight = _weights.fold(0, (sum, value) => sum + value);
  }

  final List<NcSimulationMove> moves;
  final int sourceLineCount;
  final List<String> warnings;

  late final double minX;
  late final double maxX;
  late final double minY;
  late final double maxY;
  late final double minZ;
  late final double maxZ;
  late final double cuttingDistance;
  late final double rapidDistance;
  late final double estimatedSeconds;
  late final List<double> _weights;
  late final double _totalWeight;

  bool get isEmpty => moves.isEmpty;

  NcSimulationPoint positionAt(double progress) {
    if (moves.isEmpty) return const NcSimulationPoint(0, 0, 0);
    final target = progress.clamp(0.0, 1.0) * _totalWeight;
    var walked = 0.0;
    for (var i = 0; i < moves.length; i++) {
      final next = walked + _weights[i];
      if (target <= next || i == moves.length - 1) {
        final local = ((target - walked) / _weights[i]).clamp(0.0, 1.0);
        return NcSimulationPoint.lerp(moves[i].start, moves[i].end, local);
      }
      walked = next;
    }
    return moves.last.end;
  }

  int lineAt(double progress) {
    if (moves.isEmpty) return 0;
    final target = progress.clamp(0.0, 1.0) * _totalWeight;
    var walked = 0.0;
    for (var i = 0; i < moves.length; i++) {
      walked += _weights[i];
      if (target <= walked) return moves[i].lineNumber;
    }
    return moves.last.lineNumber;
  }
}

abstract final class NcSimulationParser {
  static final RegExp _wordPattern = RegExp(
    r'([A-Z])([+-]?(?:\d+(?:\.\d*)?|\.\d+))',
  );
  static final RegExp _parentheses = RegExp(r'\([^)]*\)');

  static NcSimulation parse(String source) {
    final lines = source.replaceAll('\r', '').split('\n');
    final moves = <NcSimulationMove>[];
    final warnings = <String>[];

    var position = const NcSimulationPoint(0, 0, 0);
    var absolute = true;
    var unitScale = 1.0;
    var motion = 0;
    var feed = 1000.0;

    for (var index = 0; index < lines.length; index++) {
      var line = lines[index].toUpperCase();
      line = line.replaceAll(_parentheses, '');
      final semicolon = line.indexOf(';');
      if (semicolon >= 0) line = line.substring(0, semicolon);
      line = line.trim();
      if (line.isEmpty || line == '%') continue;

      final words = <String, List<double>>{};
      for (final match in _wordPattern.allMatches(line)) {
        final letter = match.group(1)!;
        final value = double.tryParse(match.group(2)!);
        if (value == null) continue;
        words.putIfAbsent(letter, () => <double>[]).add(value);
      }

      for (final code in words['G'] ?? const <double>[]) {
        final rounded = code.round();
        switch (rounded) {
          case 0:
          case 1:
          case 2:
          case 3:
            motion = rounded;
          case 20:
            unitScale = 25.4;
          case 21:
            unitScale = 1.0;
          case 90:
            absolute = true;
          case 91:
            absolute = false;
        }
      }

      final feedWord = words['F']?.lastOrNull;
      if (feedWord != null && feedWord > 0) feed = feedWord * unitScale;

      final xWord = words['X']?.lastOrNull;
      final yWord = words['Y']?.lastOrNull;
      final zWord = words['Z']?.lastOrNull;
      if (xWord == null && yWord == null && zWord == null) continue;

      final target = NcSimulationPoint(
        xWord == null
            ? position.x
            : absolute
                ? xWord * unitScale
                : position.x + xWord * unitScale,
        yWord == null
            ? position.y
            : absolute
                ? yWord * unitScale
                : position.y + yWord * unitScale,
        zWord == null
            ? position.z
            : absolute
                ? zWord * unitScale
                : position.z + zWord * unitScale,
      );

      if (motion == 2 || motion == 3) {
        final iWord = words['I']?.lastOrNull;
        final jWord = words['J']?.lastOrNull;
        if (iWord == null || jWord == null) {
          warnings.add('Line ${index + 1}: arc ignored because I/J is missing.');
          moves.add(
            NcSimulationMove(
              start: position,
              end: target,
              kind: NcMoveKind.cutting,
              lineNumber: index + 1,
              feed: feed,
            ),
          );
        } else {
          _addArc(
            moves: moves,
            start: position,
            target: target,
            i: iWord * unitScale,
            j: jWord * unitScale,
            clockwise: motion == 2,
            lineNumber: index + 1,
            feed: feed,
          );
        }
      } else {
        moves.add(
          NcSimulationMove(
            start: position,
            end: target,
            kind: motion == 0 ? NcMoveKind.rapid : NcMoveKind.cutting,
            lineNumber: index + 1,
            feed: feed,
          ),
        );
      }
      position = target;
    }

    return NcSimulation(
      moves: moves,
      sourceLineCount: lines.length,
      warnings: warnings,
    );
  }

  static void _addArc({
    required List<NcSimulationMove> moves,
    required NcSimulationPoint start,
    required NcSimulationPoint target,
    required double i,
    required double j,
    required bool clockwise,
    required int lineNumber,
    required double feed,
  }) {
    final centerX = start.x + i;
    final centerY = start.y + j;
    final radius = math.sqrt(i * i + j * j);
    if (radius < 0.000001) {
      moves.add(
        NcSimulationMove(
          start: start,
          end: target,
          kind: NcMoveKind.cutting,
          lineNumber: lineNumber,
          feed: feed,
        ),
      );
      return;
    }

    final startAngle = math.atan2(start.y - centerY, start.x - centerX);
    final isFullCircle =
        (target.x - start.x).abs() < 0.000001 &&
        (target.y - start.y).abs() < 0.000001;
    var endAngle = isFullCircle
        ? startAngle + (clockwise ? -2 * math.pi : 2 * math.pi)
        : math.atan2(target.y - centerY, target.x - centerX);

    if (!isFullCircle) {
      if (clockwise && endAngle >= startAngle) endAngle -= 2 * math.pi;
      if (!clockwise && endAngle <= startAngle) endAngle += 2 * math.pi;
    }

    final sweep = endAngle - startAngle;
    final segmentCount = math.max(12, (sweep.abs() * radius / 3).ceil());
    var previous = start;
    for (var step = 1; step <= segmentCount; step++) {
      final t = step / segmentCount;
      final angle = startAngle + sweep * t;
      final point = NcSimulationPoint(
        centerX + radius * math.cos(angle),
        centerY + radius * math.sin(angle),
        start.z + (target.z - start.z) * t,
      );
      moves.add(
        NcSimulationMove(
          start: previous,
          end: step == segmentCount ? target : point,
          kind: NcMoveKind.cutting,
          lineNumber: lineNumber,
          feed: feed,
        ),
      );
      previous = point;
    }
  }
}
