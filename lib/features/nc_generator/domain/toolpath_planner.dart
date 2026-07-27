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
      final total = p.roughPasses + (p.finishAllowance > 0 ? 1 : 0) + 1;
      for (var rough = 0; rough < p.roughPasses; rough++) {
        final remaining = p.roughPasses - rough;
        final offset = p.toolRadius + p.finishAllowance + remaining * p.offsetDistance;
        passes.add(MachiningPass(contour: OffsetEngine.offset(contour, offset), strategy: PassStrategy.rough, feed: p.feedRough, ordinal: passes.length + 1, total: total));
      }
      if (p.finishAllowance > 0) passes.add(MachiningPass(contour: OffsetEngine.offset(contour, p.toolRadius + p.finishAllowance), strategy: PassStrategy.semiFinish, feed: p.feedRough, ordinal: passes.length + 1, total: total));
      passes.add(MachiningPass(contour: OffsetEngine.offset(contour, p.toolRadius), strategy: PassStrategy.finish, feed: p.feedFinish, ordinal: passes.length + 1, total: total));
    }
    return ToolpathPlan(passes, source);
  }
}

class PlannerParameters {
  const PlannerParameters({required this.roughPasses,required this.offsetDistance,required this.finishAllowance,required this.toolRadius,required this.feedRough,required this.feedFinish});
  final int roughPasses, feedRough, feedFinish;
  final double offsetDistance, finishAllowance, toolRadius;
}
