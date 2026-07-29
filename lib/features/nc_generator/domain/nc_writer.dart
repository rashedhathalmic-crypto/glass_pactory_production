import 'dart:math' as math;

import 'cam_engine.dart';
import 'dxf_document.dart';
import 'machine_profile.dart';
import 'toolpath_planner.dart';

class NcWriter {
  NcWriter(this.profile, this.p);
  final MachineProfile profile;
  final NcOutputParameters p;

  String write(ToolpathPlan plan, String units) {
    final out = <String>['%', p.programNumber, '(${profile.name} CAM - OFFSET ROUGH / SEMI-FINISH / FINISH)', '(DXF:${_safe(p.drawingName)} UNITS:$units THK:${_n(p.thickness)}MM)', '(CONTOURS:${plan.source.contours.length} TOOL:D${_n(p.toolDiameter)} PASSES:${p.totalPasses} CUT-PER-PASS:${_n(p.offsetDistance)})', 'G90G40G49G80G98', 'G21G00${p.workOffset}G17', 'T${p.toolNumber.toString().padLeft(2,'0')}M06', 'S${p.spindleSpeed}M03', 'G90G00G43Z${_n(p.safeZ)}H${p.toolNumber.toString().padLeft(2,'0')}'];
    for (var index = 0; index < plan.passes.length; index++) {
      final pass = plan.passes[index], contour = pass.contour;
      final first = contour.segments.first, tangent = _tangent(first);
      final leadStart = DxfPoint(first.start.x-tangent.x*p.leadInLength, first.start.y-tangent.y*p.leadInLength);
      final leadEnd = DxfPoint(first.start.x+tangent.x*p.leadOutLength, first.start.y+tangent.y*p.leadOutLength);
      out.add('(${pass.strategy.name.toUpperCase()} ${index+1}/${plan.passes.length} ${contour.kind.name.toUpperCase()} DEPTH:${contour.depth})');
      // Absolute positioning between paths; incremental cutting is deliberate
      // and mirrors the controller-safe strategy in the reference program.
      out.add('G90G00Z${_n(p.rapidZ)}');
      out.add('G90G00X${_x(leadStart)}Y${_y(leadStart)}');
      out.add('G01Z${_n(-p.cutDepth)}F${p.plungeFeed}');
      out.add('G91G01X${_n(first.start.x-leadStart.x)}Y${_n(first.start.y-leadStart.y)}Z${_n(p.zOscillation)}F${pass.feed} (LEAD IN)');
      var position = first.start;
      for (var i = 0; i < contour.segments.length; i++) {
        final segment = contour.segments[i];
        final z = i == contour.segments.length ~/ 2 ? -2*p.zOscillation : 0.0;
        out.add(_segment(segment, position, z)); position = segment.end;
      }
      out.add('G01X${_n(leadEnd.x-position.x)}Y${_n(leadEnd.y-position.y)}Z${_n(p.zOscillation)}F${pass.feed} (LEAD OUT)');
      out.add('G90G00Z${_n(p.safeZ)}');
    }
    out.addAll(['G90G00Z${_n(p.safeZ)}','G90G00X${_n(profile.parkX)}Y${_n(profile.parkY)}','M05','M09','G49','M30','%']);
    return '${out.join('\n')}\n';
  }

  String _segment(CamSegment s, DxfPoint from, double z) {
    final dz = z == 0 ? '' : 'Z${_n(z)}';
    if (s is CamLine) return 'G01X${_n(s.end.x-from.x)}Y${_n(s.end.y-from.y)}$dz';
    final arc=s as CamArc;
    // Preserve a full circle as one native circular interpolation block.
    if (arc.fullCircle) {
      final code=arc.clockwise?'G02':'G03';
      return '${code}X0Y0I${_n(arc.center.x-from.x)}J${_n(arc.center.y-from.y)}$dz';
    }
    return '${arc.clockwise?'G02':'G03'}X${_n(arc.end.x-from.x)}Y${_n(arc.end.y-from.y)}I${_n(arc.center.x-from.x)}J${_n(arc.center.y-from.y)}$dz';
  }
  DxfPoint _tangent(CamSegment s) { if(s is CamLine){final l=s.length;return DxfPoint((s.end.x-s.start.x)/l,(s.end.y-s.start.y)/l);} final a=s as CamArc,dx=a.start.x-a.center.x,dy=a.start.y-a.center.y,l=math.max(a.radius,1e-9);return a.clockwise?DxfPoint(dy/l,-dx/l):DxfPoint(-dy/l,dx/l); }
  String _x(DxfPoint v)=>_n(v.x+p.xOffset); String _y(DxfPoint v)=>_n(v.y+p.yOffset);
  String _n(num value)=>(value.abs()<0.0000001?0:value).toStringAsFixed(profile.decimalPlaces).replaceFirst(RegExp(r'\.?0+$'),'');
  String _safe(String value)=>value.replaceAll(RegExp(r'[^A-Za-z0-9_. -]'),'_').toUpperCase();
}

class NcOutputParameters {
  const NcOutputParameters({required this.drawingName,required this.programNumber,required this.workOffset,required this.toolNumber,required this.toolDiameter,required this.thickness,required this.totalPasses,required this.roughPasses,required this.offsetDistance,required this.finishAllowance,required this.feedRough,required this.feedFinish,required this.plungeFeed,required this.spindleSpeed,required this.safeZ,required this.rapidZ,required this.leadInLength,required this.leadOutLength,required this.zOscillation,required this.cutDepth,required this.xOffset,required this.yOffset});
  final String drawingName,programNumber,workOffset; final int toolNumber,totalPasses,roughPasses,feedRough,feedFinish,plungeFeed,spindleSpeed; final double toolDiameter,thickness,offsetDistance,finishAllowance,safeZ,rapidZ,leadInLength,leadOutLength,zOscillation,cutDepth,xOffset,yOffset;
}
