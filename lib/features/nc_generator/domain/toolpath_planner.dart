import 'cam_engine.dart';
import 'dxf_document.dart';
import 'offset_engine.dart';

enum PassStrategy { rough, semiFinish, finish }

class MachiningPass {
  const MachiningPass({required this.contour, required this.strategy, required this.feed, required this.ordinal, required this.total});
  final CamContour contour;
  final PassStrategy strategy;
  final int feed, ordinal, total;
}

class ToolpathPlan {
  const ToolpathPlan(this.passes, this.source);
  final List<MachiningPass> passes;
  final CamPlan source;
}

/// Selects inside-before-outside order and expands every contour into rough,
/// semi-finish and dedicated finish paths.
class ToolpathPlanner {
  const ToolpathPlanner._();
  static ToolpathPlan plan(CamPlan source, PlannerParameters p) {
    final passes = <MachiningPass>[];
    var current = const DxfPoint(0, 0);
    final pending = [...source.contours];
    while (pending.isNotEmpty) {
      final deepest = pending.map((c) => c.depth).reduce((a,b)=>a>b?a:b);
      final candidates = pending.where((c) => c.depth == deepest).toList()..sort((a,b)=>a.start.distanceTo(current).compareTo(b.start.distanceTo(current)));
      final contour = candidates.first; pending.remove(contour); current = contour.start;
      final total = p.totalPasses;
      for (var passIndex = 0; passIndex < total; passIndex++) {
        final remaining = total - 1 - passIndex;
        final offset = p.toolRadius + remaining * p.offsetDistance;
        final isFinish = passIndex == total - 1;
        final isRough = passIndex < 2;
        passes.add(MachiningPass(
          contour: OffsetEngine.offset(contour, offset),
          strategy: isFinish ? PassStrategy.finish : (isRough ? PassStrategy.rough : PassStrategy.semiFinish),
          feed: isRough ? p.feedRough : p.feedFinish,
          ordinal: passes.length + 1,
          total: total,
        ));
      }
    }
    return ToolpathPlan(passes, source);
  }
}

class PlannerParameters {
  const PlannerParameters({required this.totalPasses,required this.offsetDistance,required this.toolRadius,required this.feedRough,required this.feedFinish});
  final int totalPasses, feedRough, feedFinish;
  final double offsetDistance, toolRadius;
}
