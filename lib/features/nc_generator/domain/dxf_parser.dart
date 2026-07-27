import 'dart:convert';
import 'dart:typed_data';

import 'dxf_document.dart';

class DxfParser {
  const DxfParser._();

  static DxfDocument parseBytes(Uint8List bytes) => parse(utf8.decode(bytes, allowMalformed: true));

  static DxfDocument parse(String source) {
    final lines = const LineSplitter().convert(source);
    if (lines.length < 2) throw const FormatException('The DXF file is empty or invalid.');
    final pairs = <_Pair>[];
    for (var i = 0; i + 1 < lines.length; i += 2) {
      final code = int.tryParse(lines[i].trim());
      if (code != null) pairs.add(_Pair(code, lines[i + 1].trim()));
    }
    final entities = <DxfEntity>[];
    var inEntities = false;
    for (var i = 0; i < pairs.length;) {
      final pair = pairs[i];
      if (pair.code == 0 && pair.value == 'SECTION' && i + 1 < pairs.length && pairs[i + 1].value == 'ENTITIES') {
        inEntities = true; i += 2; continue;
      }
      if (inEntities && pair.code == 0 && pair.value == 'ENDSEC') { inEntities = false; i++; continue; }
      if (!inEntities || pair.code != 0) { i++; continue; }
      final type = pair.value.toUpperCase();
      if (type == 'POLYLINE') {
        final headerEnd = _nextEntity(pairs, i + 1);
        final closed = (_int(pairs.sublist(i + 1, headerEnd), 70) & 1) != 0;
        final vertices = <DxfPoint>[];
        i = headerEnd;
        while (i < pairs.length && pairs[i].value == 'VERTEX') {
          final end = _nextEntity(pairs, i + 1);
          final data = pairs.sublist(i + 1, end);
          vertices.add(DxfPoint(_num(data, 10), _num(data, 20)));
          i = end;
        }
        if (i < pairs.length && pairs[i].value == 'SEQEND') i = _nextEntity(pairs, i + 1);
        if (vertices.length >= 2) entities.add(DxfPolyline(vertices, closed: closed));
        continue;
      }
      final end = _nextEntity(pairs, i + 1);
      final data = pairs.sublist(i + 1, end);
      switch (type) {
        case 'LINE':
          entities.add(DxfLine(DxfPoint(_num(data, 10), _num(data, 20)), DxfPoint(_num(data, 11), _num(data, 21))));
        case 'ARC':
          entities.add(DxfArc(DxfPoint(_num(data, 10), _num(data, 20)), _positive(data, 40), _num(data, 50), _num(data, 51)));
        case 'CIRCLE':
          entities.add(DxfCircle(DxfPoint(_num(data, 10), _num(data, 20)), _positive(data, 40)));
        case 'LWPOLYLINE':
          final vertices = <DxfPoint>[];
          double? x;
          for (final item in data) {
            if (item.code == 10) { x = double.tryParse(item.value); }
            if (item.code == 20 && x != null) { vertices.add(DxfPoint(x, double.parse(item.value))); x = null; }
          }
          if (vertices.length >= 2) entities.add(DxfPolyline(vertices, closed: (_int(data, 70) & 1) != 0));
      }
      i = end;
    }
    if (entities.isEmpty) throw const FormatException('No supported LINE, ARC, CIRCLE, POLYLINE or LWPOLYLINE entities were found.');
    return DxfDocument(entities);
  }

  static int _nextEntity(List<_Pair> pairs, int start) { var i = start; while (i < pairs.length && pairs[i].code != 0) { i++; } return i; }
  static double _num(List<_Pair> data, int code) => double.parse(data.firstWhere((p) => p.code == code, orElse: () => const _Pair(-1, '0')).value);
  static double _positive(List<_Pair> data, int code) { final value = _num(data, code); if (!value.isFinite || value <= 0) throw FormatException('Invalid DXF radius: $value'); return value; }
  static int _int(List<_Pair> data, int code) => int.tryParse(data.firstWhere((p) => p.code == code, orElse: () => const _Pair(-1, '0')).value) ?? 0;
}

class _Pair { const _Pair(this.code, this.value); final int code; final String value; }
