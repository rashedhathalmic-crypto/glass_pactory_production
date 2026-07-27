import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/helpers/download_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/page_header.dart';
import '../domain/nc_generator.dart';

class NcGeneratorScreen extends StatefulWidget {
  const NcGeneratorScreen({super.key});

  @override
  State<NcGeneratorScreen> createState() => _NcGeneratorScreenState();
}

class _NcGeneratorScreenState extends State<NcGeneratorScreen> {
  String _profile = NcGenerator.supportedProfiles.last;
  final _toolDiameter = TextEditingController(text: '94.4');
  final _toolWidth = TextEditingController(text: '24.3');
  final _thickness = TextEditingController(text: '19');
  final _workOffset = TextEditingController(text: 'G58');
  final _xCorrection = TextEditingController(text: '0');
  final _yCorrection = TextEditingController(text: '0');
  final _roughingFeed = TextEditingController(text: '1000');
  final _finishingFeed = TextEditingController(text: '2000');
  final _programNumber = TextEditingController(text: 'O0001');
  String _output = '';
  String? _error;

  Iterable<TextEditingController> get _controllers => [
    _toolDiameter,
    _toolWidth,
    _thickness,
    _workOffset,
    _xCorrection,
    _yCorrection,
    _roughingFeed,
    _finishingFeed,
    _programNumber,
  ];

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(_generate);
    }
    _generate();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  double _decimal(TextEditingController controller, String label) {
    final value = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    if (value == null) throw FormatException('$label must be a number.');
    return value;
  }

  int _integer(TextEditingController controller, String label) {
    final value = int.tryParse(controller.text.trim());
    if (value == null) throw FormatException('$label must be a whole number.');
    return value;
  }

  void _generate() {
    try {
      final output = NcGenerator.generate(
        NcParameters(
          profile: _profile,
          toolDiameter: _decimal(_toolDiameter, 'Tool diameter'),
          toolWidth: _decimal(_toolWidth, 'Tool width'),
          thickness: _decimal(_thickness, 'Glass thickness'),
          workOffset: _workOffset.text.trim().toUpperCase(),
          xCorrection: _decimal(_xCorrection, 'X correction'),
          yCorrection: _decimal(_yCorrection, 'Y correction'),
          roughingFeed: _integer(_roughingFeed, 'Roughing feed'),
          finishingFeed: _integer(_finishingFeed, 'Finishing feed'),
          programNumber: _programNumber.text.trim().toUpperCase(),
        ),
      );
      if (mounted) setState(() { _output = output; _error = null; });
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error.toString().replaceFirst('Invalid argument(s): ', ''));
      }
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _output));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('NC program copied to clipboard.')),
    );
  }

  Future<void> _download() async {
    await downloadBytes(
      bytes: Uint8List.fromList(utf8.encode(_output)),
      fileName: '${_programNumber.text.trim().toUpperCase()}_${_profile}.nc',
      mimeType: 'text/plain;charset=utf-8',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.offWhite,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1000;
          return SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 16 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: 'CNC NC Generator',
                  subtitle: 'Create machine-ready SKG1625 Shanlong L68 programs directly in your browser.',
                  actions: [
                    OutlinedButton.icon(
                      onPressed: _output.isEmpty ? null : _copy,
                      icon: const Icon(Icons.content_copy, size: 18),
                      label: const Text('Copy NC'),
                    ),
                    FilledButton.icon(
                      onPressed: _output.isEmpty ? null : _download,
                      icon: const Icon(AppIcons.download, size: 18),
                      label: const Text('Download .nc'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (compact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [_parametersCard(), const SizedBox(height: 16), _previewCard()],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 360, child: _parametersCard()),
                      const SizedBox(width: 20),
                      Expanded(child: _previewCard()),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _parametersCard() {
    return AppCard(
      title: 'Program setup',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _profile,
            decoration: const InputDecoration(labelText: 'Part profile'),
            items: NcGenerator.supportedProfiles
                .map((profile) => DropdownMenuItem(value: profile, child: Text(profile)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              _profile = value;
              _generate();
            },
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _field(_toolDiameter, 'Tool diameter', suffix: 'mm')),
            const SizedBox(width: 12),
            Expanded(child: _field(_toolWidth, 'Tool width', suffix: 'mm')),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _field(_thickness, 'Glass thickness', suffix: 'mm')),
            const SizedBox(width: 12),
            Expanded(child: _field(_workOffset, 'Work offset', numeric: false)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _field(_xCorrection, 'X correction', suffix: 'mm')),
            const SizedBox(width: 12),
            Expanded(child: _field(_yCorrection, 'Y correction', suffix: 'mm')),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _field(_roughingFeed, 'Roughing feed', suffix: 'mm/min')),
            const SizedBox(width: 12),
            Expanded(child: _field(_finishingFeed, 'Finishing feed', suffix: 'mm/min')),
          ]),
          const SizedBox(height: 14),
          _field(_programNumber, 'Program number', numeric: false),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(AppIcons.error, color: AppColors.error, size: 19),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error))),
              ]),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Generation happens locally in this browser. No workbook upload or Excel installation is required.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? suffix,
    bool numeric = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    );
  }

  Widget _previewCard() {
    final lineCount = _output.isEmpty ? 0 : '\n'.allMatches(_output).length;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Row(children: [
              const Expanded(
                child: Text('NC program preview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  _error == null ? '$lineCount lines • Ready' : 'Check parameters',
                  style: TextStyle(
                    color: _error == null ? AppColors.success : AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 600),
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: SelectableText(
              _output,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.45,
                color: Color(0xFFE5E7EB),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
