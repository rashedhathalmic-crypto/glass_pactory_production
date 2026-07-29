import 'cam_engine.dart';
import 'dxf_document.dart';
import 'machine_profile.dart';
import 'nc_writer.dart';
import 'toolpath_planner.dart';

/// Complete process configuration. Legacy `cuttingFeed`, `maxPassDepth`,
/// `leadLength` and `safeHeight` names remain accepted for API compatibility.
class NcParameters {
  const NcParameters({required this.drawingName,this.toolNumber=1,this.toolDiameter=6,this.thickness=10,this.totalPasses=5,this.roughPasses=2,this.offsetDistance=0.5,this.finishAllowance=0.2,int feedRough=1000,this.feedFinish=2000,int? cuttingFeed,this.plungeFeed=3000,this.spindleSpeed=5500,double? safeHeight,double safeZ=50,this.rapidZ=10,double? leadLength,double leadInLength=4,double leadOutLength=4,this.zOscillation=0.3,double? cutDepth,double? maxPassDepth,this.workOffset='G58',this.xOffset=0,this.yOffset=0,this.programNumber='O0001'}) : feedRough = cuttingFeed ?? feedRough, safeZ = safeHeight ?? safeZ, leadInLength = leadLength ?? leadInLength, leadOutLength = leadLength ?? leadOutLength, cutDepth = cutDepth ?? 13;
  final String drawingName,workOffset,programNumber;
  final int toolNumber,totalPasses,roughPasses,feedRough,feedFinish,plungeFeed,spindleSpeed;
  final double toolDiameter,thickness,offsetDistance,finishAllowance,safeZ,rapidZ,leadInLength,leadOutLength,zOscillation,cutDepth,xOffset,yOffset;
  void validate(){if(toolNumber<=0||toolDiameter<=0||thickness<=0||cutDepth<=0||totalPasses<2||roughPasses<0||offsetDistance<=0||finishAllowance<0||safeZ<=rapidZ||rapidZ<=0||leadInLength<0||leadOutLength<0||zOscillation<0)throw ArgumentError('Invalid toolpath dimensions or pass configuration.');if(feedRough<=0||feedFinish<=0||plungeFeed<=0||spindleSpeed<=0)throw ArgumentError('Feeds and spindle speed must be positive.');if(!RegExp(r'^G5[4-9]$').hasMatch(workOffset))throw ArgumentError('Work offset must be G54–G59.');if(!RegExp(r'^O\d{1,8}$').hasMatch(programNumber))throw ArgumentError('Program number must use the format O0001.');}
}

class NcGenerator {
  const NcGenerator._();
  static String generate(DxfDocument document,NcParameters p,{MachineProfile profile=MachineProfile.skg1625}){
    p.validate(); final geometry=CamEngine.analyze(document);
    if(geometry.contours.isEmpty)throw ArgumentError('Upload a DXF drawing first.');
    if(geometry.warnings.isNotEmpty)throw ArgumentError('${geometry.warnings.join(' ')} Repair the DXF before generating production NC.');
    final plan=ToolpathPlanner.plan(geometry,PlannerParameters(totalPasses:p.totalPasses,offsetDistance:p.offsetDistance,toolRadius:p.toolDiameter/2,feedRough:p.feedRough,feedFinish:p.feedFinish));
    return NcWriter(profile,NcOutputParameters(drawingName:p.drawingName,programNumber:p.programNumber,workOffset:p.workOffset,toolNumber:p.toolNumber,toolDiameter:p.toolDiameter,thickness:p.thickness,totalPasses:p.totalPasses,roughPasses:p.roughPasses,offsetDistance:p.offsetDistance,finishAllowance:p.finishAllowance,feedRough:p.feedRough,feedFinish:p.feedFinish,plungeFeed:p.plungeFeed,spindleSpeed:p.spindleSpeed,safeZ:p.safeZ,rapidZ:p.rapidZ,leadInLength:p.leadInLength,leadOutLength:p.leadOutLength,zOscillation:p.zOscillation,cutDepth:p.cutDepth,xOffset:p.xOffset,yOffset:p.yOffset)).write(plan,document.units.name.toUpperCase());
  }
}
