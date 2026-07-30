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

class ImageDimensionReading {
  const ImageDimensionReading({
    required this.value,
    required this.confidence,
  });

  final String value;
  final double confidence;

  factory ImageDimensionReading.fromJson(Map<String, dynamic> json) {
    return ImageDimensionReading(
      value: json['value'] as String,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}

class PdfProfileAnalysis {
  const PdfProfileAnalysis({
    required this.drawingScale,
    required this.profiles,
    this.sourceKind = 'pdf',
    this.dimensionReadings = const [],
  });

  final double drawingScale;
  final List<PdfProfileCandidate> profiles;
  final String sourceKind;
  final List<ImageDimensionReading> dimensionReadings;

  bool get isImageSource =>
      sourceKind == 'clipboardImage' || sourceKind == 'imageOcr';

  factory PdfProfileAnalysis.fromJson(Map<String, dynamic> json) {
    return PdfProfileAnalysis(
      drawingScale: (json['drawingScale'] as num).toDouble(),
      sourceKind: json['sourceKind'] as String? ?? 'pdf',
      dimensionReadings: (json['dimensionReadings'] as List<dynamic>? ??
              const <dynamic>[])
          .map(
            (reading) => ImageDimensionReading.fromJson(
              reading as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
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
