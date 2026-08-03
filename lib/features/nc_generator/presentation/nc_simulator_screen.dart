import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/helpers/file_picker_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/page_header.dart';
import '../domain/nc_simulation.dart';

class NcSimulatorScreen extends StatefulWidget {
  const NcSimulatorScreen({
    super.key,
    this.generatedProgram,
  });

  final ValueListenable<String>? generatedProgram;

  @override
  State<NcSimulatorScreen> createState() => _NcSimulatorScreenState();
}

class _NcSimulatorScreenState extends State<NcSimulatorScreen>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  late final AnimationController _animation;

  NcSimulation? _simulation;
  String? _fileName;
  String? _error;
  double _speed = 4;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) setState(() {});
      });
    widget.generatedProgram?.addListener(_loadGeneratedProgram);
    final generated = widget.generatedProgram?.value ?? '';
    if (generated.trim().isNotEmpty) {
      _codeController.text = generated;
      _parse(sourceName: 'Generated NC');
    }
  }

  @override
  void didUpdateWidget(covariant NcSimulatorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generatedProgram != widget.generatedProgram) {
      oldWidget.generatedProgram?.removeListener(_loadGeneratedProgram);
      widget.generatedProgram?.addListener(_loadGeneratedProgram);
    }
  }

  @override
  void dispose() {
    widget.generatedProgram?.removeListener(_loadGeneratedProgram);
    _animation.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _loadGeneratedProgram() {
    final source = widget.generatedProgram?.value ?? '';
    if (source.trim().isEmpty || source == _codeController.text) return;
    _codeController.text = source;
    _parse(sourceName: 'Generated NC');
  }

  Future<void> _pickNc() async {
    final files = await pickFiles(
      extensions: const ['nc', 'tap', 'txt', 'cnc'],
    );
    if (files.isEmpty) return;
    final file = files.first;
    try {
      _codeController.text = utf8.decode(file.bytes, allowMalformed: true);
      _parse(sourceName: file.fileName);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Unable to read the NC file: $error');
    }
  }

  void _parse({String? sourceName}) {
    try {
      final simulation = NcSimulationParser.parse(_codeController.text);
      if (simulation.isEmpty) {
        throw const FormatException(
          'No G00/G01/G02/G03 movement was found in the NC program.',
        );
      }
      _animation
        ..stop()
        ..value = 0;
      _updateDuration(simulation);
      setState(() {
        _simulation = simulation;
        _fileName = sourceName ?? _fileName ?? 'Pasted NC';
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _simulation = null;
        _error = error.toString().replaceFirst('FormatException: ', '');
      });
    }
  }

  void _updateDuration(NcSimulation simulation) {
    final seconds = (simulation.estimatedSeconds / _speed)
        .clamp(3.0, 180.0)
        .toDouble();
    _animation.duration = Duration(milliseconds: (seconds * 1000).round());
  }

  void _togglePlay() {
    if (_simulation == null) return;
    if (_animation.isAnimating) {
      _animation.stop();
    } else {
      if (_animation.value >= 1) _animation.value = 0;
      _animation.forward();
    }
    setState(() {});
  }

  void _restart() {
    if (_simulation == null) return;
    _animation
      ..stop()
      ..value = 0;
    setState(() {});
  }

  void _changeSpeed(double value) {
    final wasAnimating = _animation.isAnimating;
    final progress = _animation.value;
    _animation.stop();
    setState(() => _speed = value);
    final simulation = _simulation;
    if (simulation == null) return;
    _updateDuration(simulation);
    _animation.value = progress;
    if (wasAnimating) _animation.forward();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.offWhite,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1050;
          return SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 16 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: 'NC Toolpath Simulator',
                  subtitle:
                      'Verify the final part size, program time and machine coordinates before running the machine.',
                  actions: [
                    OutlinedButton.icon(
                      onPressed: _pickNc,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload NC'),
                    ),
                    FilledButton.icon(
                      onPressed: _codeController.text.trim().isEmpty
                          ? null
                          : () => _parse(),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Load simulation'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (compact)
                  Column(
                    children: [
                      _sourceCard(),
                      const SizedBox(height: 16),
                      _simulationColumn(),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 390, child: _sourceCard()),
                      const SizedBox(width: 20),
                      Expanded(child: _simulationColumn()),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sourceCard() {
    return AppCard(
      title: 'NC program source',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_fileName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _fileName!,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkBlue,
                ),
              ),
            ),
          TextField(
            controller: _codeController,
            minLines: 18,
            maxLines: 28,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              alignLabelWithHint: true,
              labelText: 'Paste NC / G-code',
              hintText: 'G90 G21\nG00 X0 Y0\nG01 X100 Y0 F1000',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    final text = data?.text;
                    if (text == null || text.trim().isEmpty) return;
                    _codeController.text = text;
                    _parse(sourceName: 'Clipboard NC');
                  },
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Paste'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _codeController.text.trim().isEmpty
                      ? null
                      : () => _parse(),
                  icon: const Icon(Icons.precision_manufacturing),
                  label: const Text('Simulate'),
                ),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
        ],
      ),
    );
  }

  Widget _simulationColumn() {
    final simulation = _simulation;
    return Column(
      children: [
        AppCard(
          title: '2D machine view',
          child: SizedBox(
            height: 520,
            width: double.infinity,
            child: simulation == null
                ? const Center(
                    child: Text('Generate or upload an NC program to simulate it.'),
                  )
                : AnimatedBuilder(
                    animation: _animation,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _NcSimulationPainter(
                          simulation: simulation,
                          progress: _animation.value,
                        ),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: _positionBadge(simulation),
                        ),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 16),
        if (simulation != null) ...[
          _controls(),
          const SizedBox(height: 16),
          _resultSummary(simulation),
        ],
      ],
    );
  }

  Widget _positionBadge(NcSimulation simulation) {
    final position = simulation.positionAt(_animation.value);
    final line = simulation.lineAt(_animation.value);
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(blurRadius: 8, color: Color(0x22000000)),
        ],
      ),
      child: Text(
        'Line $line   X ${_n(position.x)}   Y ${_n(position.y)}   Z ${_n(position.z)} mm',
        style: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _controls() {
    return AppCard(
      title: 'Playback',
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filled(
                onPressed: _togglePlay,
                icon: Icon(
                  _animation.isAnimating ? Icons.pause : Icons.play_arrow,
                ),
                tooltip: _animation.isAnimating ? 'Pause' : 'Play',
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: _restart,
                icon: const Icon(Icons.replay),
                tooltip: 'Restart',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, _) => Slider(
                    value: _animation.value,
                    onChanged: (value) {
                      _animation.stop();
                      _animation.value = value;
                      setState(() {});
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '${(_animation.value * 100).round()}%',
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Speed'),
              Expanded(
                child: Slider(
                  min: 1,
                  max: 20,
                  divisions: 19,
                  value: _speed,
                  label: '${_speed.round()}×',
                  onChanged: _changeSpeed,
                ),
              ),
              SizedBox(
                width: 48,
                child: Text('${_speed.round()}×'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultSummary(NcSimulation simulation) {
    final bounds = _finalCuttingBounds(simulation);
    final duration = Duration(seconds: simulation.estimatedSeconds.round());
    final end = simulation.moves.last.end;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final current = simulation.positionAt(_animation.value);
        final stats = <(String, String, IconData)>[
          (
            'Final part dimensions',
            'X ${_n(bounds.width)} × Y ${_n(bounds.height)} mm',
            Icons.straighten,
          ),
          (
            'Estimated program time',
            _duration(duration),
            Icons.timer_outlined,
          ),
          (
            'Current coordinates',
            'X ${_n(current.x)}   Y ${_n(current.y)}   Z ${_n(current.z)} mm',
            Icons.my_location,
          ),
          (
            'Program end coordinates',
            'X ${_n(end.x)}   Y ${_n(end.y)}   Z ${_n(end.z)} mm',
            Icons.flag_outlined,
          ),
        ];

        return AppCard(
          title: 'Final result after NC program',
          child: Column(
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 330,
                  mainAxisExtent: 92,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: stats.length,
                itemBuilder: (context, index) {
                  final stat = stats[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.offWhite,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Icon(stat.$3, color: AppColors.darkBlue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stat.$1,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                stat.$2,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (simulation.warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    simulation.warnings.join('\n'),
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  _NcBounds _finalCuttingBounds(NcSimulation simulation) {
    final groups = <List<NcSimulationPoint>>[];
    var current = <NcSimulationPoint>[];

    void finishGroup() {
      if (current.length >= 2) groups.add(current);
      current = <NcSimulationPoint>[];
    }

    for (final move in simulation.moves) {
      if (move.kind == NcMoveKind.cutting && move.planarLength > .000001) {
        if (current.isEmpty) current.add(move.start);
        current.add(move.end);
      } else if (move.kind == NcMoveKind.rapid && current.isNotEmpty) {
        finishGroup();
      }
    }
    finishGroup();

    final points = groups.isNotEmpty
        ? groups.last
        : simulation.moves
            .expand((move) => <NcSimulationPoint>[move.start, move.end])
            .toList(growable: false);
    return _NcBounds.fromPoints(points);
  }

  String _n(double value) {
    final clean = value.abs() < .0001 ? 0.0 : value;
    return clean.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _duration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }
}

class _NcBounds {
  const _NcBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  factory _NcBounds.fromPoints(List<NcSimulationPoint> points) {
    if (points.isEmpty) {
      return const _NcBounds(minX: 0, maxX: 0, minY: 0, maxY: 0);
    }
    return _NcBounds(
      minX: points.map((point) => point.x).reduce(math.min),
      maxX: points.map((point) => point.x).reduce(math.max),
      minY: points.map((point) => point.y).reduce(math.min),
      maxY: points.map((point) => point.y).reduce(math.max),
    );
  }

  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  double get width => maxX - minX;
  double get height => maxY - minY;
}

class _NcSimulationPainter extends CustomPainter {
  const _NcSimulationPainter({
    required this.simulation,
    required this.progress,
  });

  final NcSimulation simulation;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (simulation.moves.isEmpty) return;

    const padding = 34.0;
    final width = math.max(simulation.maxX - simulation.minX, 1.0);
    final height = math.max(simulation.maxY - simulation.minY, 1.0);
    final scale = math.min(
      (size.width - padding * 2) / width,
      (size.height - padding * 2) / height,
    );
    final offsetX = (size.width - width * scale) / 2;
    final offsetY = (size.height - height * scale) / 2;

    Offset map(NcSimulationPoint point) => Offset(
          offsetX + (point.x - simulation.minX) * scale,
          size.height - offsetY - (point.y - simulation.minY) * scale,
        );

    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    const divisions = 10;
    for (var i = 0; i <= divisions; i++) {
      final x = offsetX + width * scale * i / divisions;
      final y = offsetY + height * scale * i / divisions;
      canvas.drawLine(
        Offset(x, offsetY),
        Offset(x, size.height - offsetY),
        gridPaint,
      );
      canvas.drawLine(
        Offset(offsetX, y),
        Offset(size.width - offsetX, y),
        gridPaint,
      );
    }

    final rapidPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final cuttingPaint = Paint()
      ..color = AppColors.darkBlue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final completedPaint = Paint()
      ..color = const Color(0xFF16A34A)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (final move in simulation.moves) {
      if (move.planarLength < .000001) continue;
      canvas.drawLine(
        map(move.start),
        map(move.end),
        move.kind == NcMoveKind.rapid ? rapidPaint : cuttingPaint,
      );
    }

    final currentPosition = simulation.positionAt(progress);
    final currentMoveIndex = simulation.moveIndexAt(progress);
    for (var i = 0; i < currentMoveIndex; i++) {
      final move = simulation.moves[i];
      if (move.planarLength < .000001) continue;
      canvas.drawLine(map(move.start), map(move.end), completedPaint);
    }

    final tool = map(currentPosition);
    canvas.drawCircle(
      tool,
      8,
      Paint()
        ..color = const Color(0xFFDC2626)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      tool,
      13,
      Paint()
        ..color = const Color(0xFFDC2626)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _NcSimulationPainter oldDelegate) {
    return oldDelegate.simulation != simulation || oldDelegate.progress != progress;
  }
}
