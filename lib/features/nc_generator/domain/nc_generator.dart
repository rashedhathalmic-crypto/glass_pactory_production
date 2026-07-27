import 'dxf_document.dart';

class NcParameters {
  const NcParameters({required this.drawingName, this.toolNumber = 1, this.toolDiameter = 6, this.thickness = 19, this.workOffset = 'G54', this.xOffset = 0, this.yOffset = 0, this.plungeFeed = 300, this.cuttingFeed = 1200, this.safeHeight = 10, this.programNumber = 'O0001'});
  final String drawingName;
  final int toolNumber;
  final double toolDiameter, thickness, xOffset, yOffset, safeHeight;
  final String workOffset, programNumber;
  final int plungeFeed, cuttingFeed;
  void validate() {
    if (toolNumber <= 0 || toolDiameter <= 0 || thickness <= 0 || safeHeight <= 0) throw ArgumentError('Tool, thickness and safe height must be positive.');
    if (plungeFeed <= 0 || cuttingFeed <= 0) throw ArgumentError('Feed rates must be positive.');
    if (!RegExp(r'^G5[4-9]$').hasMatch(workOffset)) throw ArgumentError('Work offset must be G54–G59.');
    if (!RegExp(r'^O\d{1,8}$').hasMatch(programNumber)) throw ArgumentError('Program number must use the format O0001.');
  }
}

class NcGenerator {
  const NcGenerator._();
  static String generate(DxfDocument document, NcParameters p) {
    p.validate();
    if (document.entities.isEmpty) throw ArgumentError('Upload a DXF drawing first.');
    final out = <String>['%', p.programNumber, '(DXF:${_safe(p.drawingName)}/ THK ${_n(p.thickness)}MM)', '(TOOL T${p.toolNumber}: DIA ${_n(p.toolDiameter)}MM)', 'G90G40G49G80G17G21', '${p.workOffset}', 'T${p.toolNumber}M06', 'S5500M03', 'G00G43Z${_n(p.safeHeight)}H${p.toolNumber.toString().padLeft(2, '0')}'];
    for (final entity in document.entities) {
      if (entity is DxfLine) _path(out, entity.start, p, ['G01X${_x(entity.end, p)}Y${_y(entity.end, p)}F${p.cuttingFeed}']);
      if (entity is DxfPolyline) {
        final moves = entity.vertices.skip(1).map((v) => 'G01X${_x(v, p)}Y${_y(v, p)}F${p.cuttingFeed}').toList();
        if (entity.closed) moves.add('G01X${_x(entity.vertices.first, p)}Y${_y(entity.vertices.first, p)}F${p.cuttingFeed}');
        _path(out, entity.vertices.first, p, moves);
      }
      if (entity is DxfArc) {
        final i = entity.center.x - entity.start.x, j = entity.center.y - entity.start.y;
        _path(out, entity.start, p, ['${entity.clockwise ? 'G02' : 'G03'}X${_x(entity.end, p)}Y${_y(entity.end, p)}I${_n(i)}J${_n(j)}F${p.cuttingFeed}']);
      }
      if (entity is DxfCircle) {
        final start = DxfPoint(entity.center.x + entity.radius, entity.center.y);
        _path(out, start, p, ['G03X${_x(start, p)}Y${_y(start, p)}I${_n(-entity.radius)}J0F${p.cuttingFeed}']);
      }
    }
    out.addAll(['G00Z${_n(p.safeHeight)}', 'M05', 'G49', 'M30', '%']);
    return '${out.join('\n')}\n';
  }
  static void _path(List<String> out, DxfPoint start, NcParameters p, List<String> moves) { out.addAll(['G00Z${_n(p.safeHeight)}', 'G00X${_x(start, p)}Y${_y(start, p)}', 'G01Z${_n(-p.thickness)}F${p.plungeFeed}', ...moves]); }
  static String _x(DxfPoint v, NcParameters p) => _n(v.x + p.xOffset);
  static String _y(DxfPoint v, NcParameters p) => _n(v.y + p.yOffset);
  static String _safe(String value) => value.replaceAll(RegExp(r'[^A-Za-z0-9_. -]'), '_').toUpperCase();
  static String _n(num value) => (value.abs() < 0.0000001 ? 0 : value).toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');
}
