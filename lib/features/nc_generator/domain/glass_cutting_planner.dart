import 'cam_engine.dart';
import 'dxf_document.dart';
import 'offset_engine.dart';

/// Experimental V2 glass cutting planner. Geometry only: never machine-ready
/// without a verified edge-entry route, fixture clearance and machine profile.
class GlassCuttingPlan {
  const GlassCuttingPlan({required this.paths, required this.warnings});
  final List<CamContour> paths;
  final List<String> warnings;
  bool get requiresReview => warnings.isNotEmpty;
}

class GlassCuttingPlanner {
  const GlassCuttingPlanner._();

  /// The 8 mm tool is the user's nominal measurement, not a calibrated value.
  /// [retainInterior] specifies the material to keep for a single contour.
  /// Interior retention places the cutter outside the drawing; an opening
  /// places the cutter inside it.
  static GlassCuttingPlan preview(
    CamContour contour, {
    double toolDiameterMm = 8,
    required bool retainInterior,
  }) {
    if (!toolDiameterMm.isFinite || toolDiameterMm <= 0) {
      throw ArgumentError.value(toolDiameterMm, 'toolDiameterMm');
    }
    if (!contour.closed || contour.segments.isEmpty) {
      throw ArgumentError('Cutting requires a closed nonempty contour.');
    }
    final radius = toolDiameterMm / 2;
    // OffsetEngine interprets external as outward, hole as inward.
    final tagged = CamContour(
      segments: contour.segments,
      closed: true,
      signedArea: contour.signedArea,
      kind: retainInterior ? ContourKind.external : ContourKind.hole,
      depth: contour.depth,
    );
    final path = OffsetEngine.offset(tagged, radius);
    return GlassCuttingPlan(
      paths: [path],
      warnings: const [
        'Preview only: no validated entry from the glass edge.',
        'Verify stock boundary, fixture clearance, tool diameter, cooling and Z clearance.',
        'Do not export or execute machine code from this preview.',
      ],
    );
  }

  static GlassCuttingPlan previewDocument(
    DxfDocument document, {
    double toolDiameterMm = 8,
    required bool retainInterior,
  }) {
    final analyzed = CamEngine.analyze(document);
    if (analyzed.warnings.isNotEmpty) {
      throw StateError(analyzed.warnings.join(' '));
    }
    final paths = <CamContour>[];
    final warnings = <String>[];
    for (final contour in analyzed.contours) {
      final result = preview(
        contour,
        toolDiameterMm: toolDiameterMm,
        retainInterior: retainInterior,
      );
      paths.addAll(result.paths);
      warnings.addAll(result.warnings);
    }
    return GlassCuttingPlan(paths: paths, warnings: warnings.toSet().toList());
  }
}
