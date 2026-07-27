class NcParameters {
  const NcParameters({
    required this.profile,
    this.toolDiameter = 94.4,
    this.toolWidth = 24.3,
    this.thickness = 19,
    this.workOffset = 'G58',
    this.xCorrection = 0,
    this.yCorrection = 0,
    this.roughingFeed = 1000,
    this.finishingFeed = 2000,
    this.programNumber = 'O0001',
  });

  final String profile;
  final double toolDiameter;
  final double toolWidth;
  final double thickness;
  final String workOffset;
  final double xCorrection;
  final double yCorrection;
  final int roughingFeed;
  final int finishingFeed;
  final String programNumber;

  void validate() {
    if (!NcGenerator.supportedProfiles.contains(profile)) {
      throw ArgumentError.value(profile, 'profile', 'Unsupported profile');
    }
    if (toolDiameter <= 0 || toolWidth <= 0 || thickness <= 0) {
      throw ArgumentError('Tool dimensions and thickness must be positive.');
    }
    if (!RegExp(r'^G5[4-9]$').hasMatch(workOffset)) {
      throw ArgumentError('Work offset must be a G54–G59 coordinate system.');
    }
    if (roughingFeed <= 0 || finishingFeed <= 0) {
      throw ArgumentError('Feed rates must be positive.');
    }
    if (!RegExp(r'^O\d{1,8}$').hasMatch(programNumber)) {
      throw ArgumentError('Program number must use the format O0001.');
    }
  }
}

class NcGenerator {
  const NcGenerator._();

  static const supportedProfiles = <String>[
    '129-122-03-210',
    '129-122-03-102',
    '129-122-03-211',
  ];

  static const Map<String, List<_GeometryRule>> _rules = {
    '129-122-03-210': [
      _GeometryRule(.414214, -5, -1),
      _GeometryRule(.08284, 352, 1, 'h'),
      _GeometryRule(.05858, 5, 1),
      _GeometryRule(.0791, 108.12179, 1, 'y'),
      _GeometryRule(.05662, 5.64571, 1),
      _GeometryRule(.04972, 4.95813, -1),
      _GeometryRule(.08226, 352.08373, -1, 'x'),
      _GeometryRule(.01071, 45.85267, 1),
      _GeometryRule(.06803, 4.95813, -1),
      _GeometryRule(.05974, 4.35429, -1),
      _GeometryRule(.08669, 155.26588, -1, 'y'),
      _GeometryRule(0, 0, 1),
      _GeometryRule(.05858, 5, 1),
      _GeometryRule(.05858, 5, -1),
      _GeometryRule(.05858, 5, 1),
      _GeometryRule(0, 0, 1),
      _GeometryRule(0, 0, 1),
    ],
    '129-122-03-102': [
      _GeometryRule(.414214, -5, -1),
      _GeometryRule(.08793, 386.41309, 1, 'h'),
      _GeometryRule(.05994, 4.15153, 1),
      _GeometryRule(.07844, 231.7593, 1, 'y'),
      _GeometryRule(.04565, 5.5367, 1),
      _GeometryRule(.04791, 5.81121, -1),
      _GeometryRule(.07755, 344.88384, -1, 'x'),
      _GeometryRule(.00952, 42.33704, 1),
      _GeometryRule(.06747, 4.96275, -1),
      _GeometryRule(.05969, 4.39079, -1),
      _GeometryRule(.08646, 275.16974, -1, 'y'),
      _GeometryRule(.01351, 39.90682, -1),
      _GeometryRule(.07114, 4.92748, 1),
      _GeometryRule(.05858, 5, -1),
      _GeometryRule(.05858, 5, 1),
      _GeometryRule(0, 0, 1),
      _GeometryRule(0, 0, 1),
    ],
    '129-122-03-211': [
      _GeometryRule(.414214, -5, -1),
      _GeometryRule(.08284, 352, 1, 'h'),
      _GeometryRule(.05858, 5, 1),
      _GeometryRule(.08088, 168.16505, 1, 'y'),
      _GeometryRule(.05766, 5.33578, 1),
      _GeometryRule(.05391, 4.98871, -1),
      _GeometryRule(.08269, 352.02257, -1, 'x'),
      _GeometryRule(.00556, 23.69383, 1),
      _GeometryRule(.06341, 4.98871, -1),
      _GeometryRule(.05929, 4.66422, -1),
      _GeometryRule(.08482, 192.53043, -1, 'y'),
      _GeometryRule(0, 0, 1),
      _GeometryRule(.05858, 5, 1),
      _GeometryRule(.05858, 5, -1),
      _GeometryRule(.05858, 5, 1),
      _GeometryRule(0, 0, 1),
      _GeometryRule(0, 0, 1),
    ],
  };

  static String generate(NcParameters parameters) {
    parameters.validate();
    final radius = parameters.toolDiameter / 2;
    final depth =
        (parameters.toolWidth - parameters.thickness) / 2 +
        parameters.thickness;
    final takes = [radius + 1.5, radius + .4, radius + .2, radius];
    final starts = takes
        .map((take) => -(take + parameters.yCorrection / 2))
        .toList();
    final geometry = _geometry(parameters, takes);
    final lines = <String>[
      '%',
      parameters.programNumber,
      '(PART NAME/NUMBER:${parameters.profile}/ THK ${_number(parameters.thickness)}MM/PERIMETER)',
      '(TOOL:ØX${_number(parameters.toolDiameter)}MM/THK${_number(parameters.toolWidth)}MM)',
      'S${parameters.toolDiameter < 110 ? 5500 : 3800}M03',
      'G90G40G49G80G98',
      'G21G00${parameters.workOffset}G17',
      'T01M06',
      'G90G00G43Z50,0H01',
      'G90G00X${_number(-radius)}Y${_number(-radius - 10)}',
      'Z10,0',
      'G01Z${_number(-depth)}F3000',
      '',
      'G01X${_number(-radius)}Y${_number(starts.first)}F${parameters.roughingFeed}',
      '',
    ];

    for (var cut = 0; cut < 4; cut++) {
      final feed = cut < 2
          ? parameters.roughingFeed
          : parameters.finishingFeed;
      lines.addAll([
        'G90G01X${_number(geometry[0][cut])}Y${_number(starts[cut])}Z${_number(-depth)}${cut == 0 ? 'F$feed' : ''}',
        'G91G01X${_number(geometry[1][cut])}Y${_number(geometry[15][cut])}Z0,3',
        'X${_number(geometry[2][cut])}Y${_number(geometry[12][cut])}',
        'X${_number(geometry[11][cut])}Y${_number(geometry[3][cut])}',
        'X${_number(geometry[5][cut])}Y${_number(geometry[4][cut])}',
        'X${_number(geometry[6][cut])}Y${_number(geometry[7][cut])}Z-0,3',
        'X${_number(geometry[8][cut])}Y${_number(geometry[9][cut])}',
        'X${_number(geometry[16][cut])}Y${_number(geometry[10][cut])}',
        'X${_number(geometry[14][cut])}Y${_number(geometry[13][cut])}',
        '',
      ]);
    }

    lines.addAll(lines.sublist(lines.length - 10));
    lines.addAll([
      'X5,0Y-5,0',
      '',
      'G90G00X-60,0Y-60,0',
      'Z50,0',
      'X-400,0Y300,0',
      'M05',
      'M09',
      'G49',
      'M30',
      '%',
    ]);
    return '${lines.join('\n')}\n';
  }

  static List<List<double>> _geometry(
    NcParameters parameters,
    List<double> takes,
  ) {
    final corrections = {
      '': 0.0,
      'h': parameters.xCorrection / 2,
      'x': parameters.xCorrection,
      'y': parameters.yCorrection,
    };
    return _rules[parameters.profile]!.map((rule) {
      return List.generate(takes.length, (cut) {
        final multiplier = cut == 0 ? 1 : 10;
        return rule.sign *
            (rule.slope * takes[cut] * multiplier +
                rule.intercept +
                corrections[rule.correction]!);
      });
    }).toList();
  }

  static String _number(num value) {
    final normalized = value.abs() < 5e-12 ? 0.0 : value.toDouble();
    return normalized
        .toStringAsFixed(8)
        .replaceFirst(RegExp(r'\.?0+$'), '')
        .replaceAll('.', ',');
  }
}

class _GeometryRule {
  const _GeometryRule(
    this.slope,
    this.intercept,
    this.sign, [
    this.correction = '',
  ]);

  final double slope;
  final double intercept;
  final int sign;
  final String correction;
}
