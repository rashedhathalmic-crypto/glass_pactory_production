import 'dart:convert';
import 'dart:typed_data';
import 'dxf_document.dart';

class DxfParser {
  const DxfParser._();
  static DxfDocument parseBytes(Uint8List bytes) => parse(utf8.decode(bytes, allowMalformed: true));
  static DxfDocument parse(String source) {
    final lines = const LineSplitter().convert(source);
    final pairs = <_Pair>[];
    for (var i = 0; i + 1 < lines.length; i += 2) { final code = int.tryParse(lines[i].trim()); if (code != null) pairs.add(_Pair(code, lines[i + 1].trim())); }
    final entities = <DxfEntity>[], unsupported = <String>[];
    var inEntities = false;
    for (var i = 0; i < pairs.length;) {
      if (pairs[i].code == 0 && pairs[i].value.toUpperCase() == 'SECTION' && i + 1 < pairs.length && pairs[i + 1].value.toUpperCase() == 'ENTITIES') { inEntities = true; i += 2; continue; }
      if (inEntities && pairs[i].code == 0 && pairs[i].value.toUpperCase() == 'ENDSEC') { inEntities = false; i++; continue; }
      if (!inEntities || pairs[i].code != 0) { i++; continue; }
      final type = pairs[i].value.toUpperCase();
      if (type == 'POLYLINE') {
        final headerEnd = _next(pairs, i + 1), vertices = <DxfVertex>[];
        final closed = _int(pairs.sublist(i + 1, headerEnd), 70) & 1 != 0;
        i = headerEnd;
        while (i < pairs.length && pairs[i].value.toUpperCase() == 'VERTEX') { final end = _next(pairs, i + 1), data = pairs.sublist(i + 1, end); vertices.add(DxfVertex(DxfPoint(_num(data, 10), _num(data, 20)), bulge: _num(data, 42))); i = end; }
        if (i < pairs.length && pairs[i].value.toUpperCase() == 'SEQEND') i = _next(pairs, i + 1);
        if (vertices.length >= 2) entities.add(DxfPolyline(vertices, closed: closed));
        continue;
      }
      final end = _next(pairs, i + 1), data = pairs.sublist(i + 1, end);
      switch (type) {
        case 'LINE': entities.add(DxfLine(DxfPoint(_num(data, 10), _num(data, 20)), DxfPoint(_num(data, 11), _num(data, 21))));
        case 'ARC': entities.add(DxfArc(DxfPoint(_num(data, 10), _num(data, 20)), _radius(data), _num(data, 50), _num(data, 51)));
        case 'CIRCLE': entities.add(DxfCircle(DxfPoint(_num(data, 10), _num(data, 20)), _radius(data)));
        case 'LWPOLYLINE':
          final vertices = <DxfVertex>[];
          for (var n = 0; n < data.length; n++) if (data[n].code == 10) { final x = double.parse(data[n].value); double y = 0, bulge = 0; for (var k = n + 1; k < data.length && data[k].code != 10; k++) { if (data[k].code == 20) y = double.parse(data[k].value); if (data[k].code == 42) bulge = double.parse(data[k].value); } vertices.add(DxfVertex(DxfPoint(x, y), bulge: bulge)); }
          if (vertices.length >= 2) entities.add(DxfPolyline(vertices, closed: _int(data, 70) & 1 != 0));
        case 'VERTEX': break;
        default: if (!const {'SEQEND', 'ENDSEC', 'EOF'}.contains(type)) unsupported.add(type);
      }
      i = end;
    }
    if (entities.isEmpty) throw const FormatException('No supported LINE, ARC, CIRCLE, POLYLINE or LWPOLYLINE entities were found.');
    return DxfDocument(entities, unsupportedEntities: unsupported.toSet().toList());
  }
  static int _next(List<_Pair> p, int i) { while (i < p.length && p[i].code != 0) i++; return i; }
  static double _num(List<_Pair> d, int code) => double.tryParse(d.where((p) => p.code == code).firstOrNull?.value ?? '0') ?? 0;
  static int _int(List<_Pair> d, int code) => int.tryParse(d.where((p) => p.code == code).firstOrNull?.value ?? '0') ?? 0;
  static double _radius(List<_Pair> d) { final r = _num(d, 40); if (r <= 0 || !r.isFinite) throw FormatException('Invalid DXF radius: $r'); return r; }
}
class _Pair { const _Pair(this.code, this.value); final int code; final String value; }
