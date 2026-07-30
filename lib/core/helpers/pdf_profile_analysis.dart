class PdfProfilePoint {
  const PdfProfilePoint(this.x, this.y);

  final double x;
  final double y;

  factory PdfProfilePoint.fromJson(List<dynamic> json) {
    return PdfProfilePoint(
      (json[0] as num).toDouble(),
      (json[1] as num).toDouble(),
    );
  }
}

class PdfProfileCandidate {
  const PdfProfileCandidate({
    required this.id,
    required this.suggested,
    required this.inferredClosure,
    required this.vertexCount,
    required this.width,
    required this.height,
    required this.points,
  });

  final int id;
  final bool suggested;
  final bool inferredClosure;
  final int vertexCount;
  final double width;
  final double height;
  final List<PdfProfilePoint> points;

  factory PdfProfileCandidate.fromJson(Map<String, dynamic> json) {
    return PdfProfileCandidate(
      id: json['id'] as int,
      suggested: json['suggested'] as bool? ?? false,
      inferredClosure: json['inferredClosure'] as bool? ?? false,
      vertexCount: json['vertexCount'] as int,
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      points: (json['points'] as List<dynamic>)
          .map((point) => PdfProfilePoint.fromJson(point as List<dynamic>))
          .toList(growable: false),
    );
  }
}

class PdfProfileAnalysis {
  const PdfProfileAnalysis({
    required this.drawingScale,
    required this.profiles,
  });

  final double drawingScale;
  final List<PdfProfileCandidate> profiles;

  factory PdfProfileAnalysis.fromJson(Map<String, dynamic> json) {
    return PdfProfileAnalysis(
      drawingScale: (json['drawingScale'] as num).toDouble(),
      profiles: (json['profiles'] as List<dynamic>)
          .map(
            (profile) => PdfProfileCandidate.fromJson(
              profile as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }
}
