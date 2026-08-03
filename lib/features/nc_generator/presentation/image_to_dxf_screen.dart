import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/helpers/download_helper.dart';
import '../../../core/helpers/file_picker_helper.dart';
import '../../../core/helpers/pdf_profile_analysis.dart';
import '../../../core/helpers/pdf_to_dxf_helper.dart';
import '../../../core/helpers/picked_file.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/page_header.dart';
import '../domain/image_dimension_geometry.dart';
import '../domain/image_profile_features.dart';

part 'image_to_dxf_screen_editor.dart';
part 'image_to_dxf_screen_verification.dart';

enum _ManualValueMode { none, horizontal, vertical, angle, chamfer }

class ImageToDxfScreen extends StatefulWidget {
  const ImageToDxfScreen({super.key});

  @override
  State<ImageToDxfScreen> createState() => _ImageToDxfScreenState();
}

class _ImageToDxfScreenState extends State<ImageToDxfScreen> {
  final List<TextEditingController> _valueControllers = [];
  final List<ImageDimensionReading> _readings = [];

  PickedFile? _sourceFile;
  Uint8List? _previewBytes;
  PdfProfileAnalysis? _analysis;
  int _selectedProfileIndex = 0;
  bool _busy = false;
  bool _confirmed = false;
  String? _error;
  String _outputBaseName = 'DRAWING';
  _ManualValueMode _manualMode = _ManualValueMode.none;

  PdfProfileCandidate? get _baseProfile {
    final profiles = _analysis?.profiles;
    if (profiles == null || profiles.isEmpty) return null;
    final index = _selectedProfileIndex.clamp(0, profiles.length - 1).toInt();
    return profiles[index];
  }

  List<double?> get _values => List<double?>.generate(
        math.min(_readings.length, _valueControllers.length),
        (index) => double.tryParse(
          _valueControllers[index].text.trim().replaceAll(',', '.'),
        ),
        growable: false,
      );

  PdfProfileCandidate? get _dimensionedProfile {
    final base = _baseProfile;
    if (base == null) return null;
    final readings = <ImageDimensionReading>[];
    final values = <double?>[];
    final parsed = _values;
    for (var index = 0; index < parsed.length; index++) {
      if (!_readings[index].isLinear) continue;
      readings.add(_readings[index]);
      values.add(parsed[index]);
    }
    if (readings.isEmpty) return null;
    return ImageDimensionGeometry.rebuild(
      base: base,
      readings: readings,
      values: values,
    );
  }

  PdfProfileCandidate? get _rebuiltProfile {
    final dimensioned = _dimensionedProfile;
    if (dimensioned == null) return null;
    return ImageProfileFeatures.apply(
      profile: dimensioned,
      readings: _readings,
      values: _values,
    );
  }

  @override
  void dispose() {
    for (final controller in _valueControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _newController(String value) {
    final controller = TextEditingController(text: value);
    controller.addListener(_valueChanged);
    return controller;
  }

  void _setReadings(List<ImageDimensionReading> readings) {
    for (final controller in _valueControllers) {
      controller.dispose();
    }
    _valueControllers
      ..clear()
      ..addAll(readings.map((reading) => _newController(reading.value)));
    _readings
      ..clear()
      ..addAll(readings);
  }

  void _valueChanged() {
    if (!mounted) return;
    setState(() {
      _confirmed = false;
      _error = null;
    });
  }

  Future<void> _pickAndAnalyze() async {
    final files = await pickFiles(
      extensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
    );
    if (files.isEmpty || !mounted) return;
    final file = files.first;
    final isPdf = file.fileName.toLowerCase().endsWith('.pdf');

    setState(() {
      _sourceFile = file;
      _previewBytes = null;
      _analysis = null;
      _selectedProfileIndex = 0;
      _busy = true;
      _confirmed = false;
      _manualMode = _ManualValueMode.none;
      _error = null;
      _outputBaseName = file.fileName.replaceAll(
        RegExp(r'\.(pdf|png|jpe?g|webp)$', caseSensitive: false),
        '',
      );
      _setReadings(const []);
    });

    try {
      final preview = isPdf
          ? await renderPdfFirstPagePng(bytes: file.bytes)
          : file.bytes;
      final analysis = await analyzeDrawingImage(
        bytes: preview,
        contentType: 'image/png',
      );
      if (analysis.profiles.isEmpty) {
        throw const FormatException(
          'لم يتم العثور على محيط مغلق واضح. اختر صورة أوضح أو قص الصفحة حول الرسمة.',
        );
      }
      if (!mounted) return;
      setState(() {
        _previewBytes = preview;
        _analysis = analysis;
        _selectedProfileIndex = 0;
        _setReadings(analysis.dimensionReadings);
        if (!analysis.dimensionReadings.any((reading) => reading.isLinear)) {
          _error =
              'أضف بُعدًا واحدًا على الأقل بالملم لتحديد مقياس القطعة، ثم أضف الزوايا والشنفر.';
        }
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error
              .toString()
              .replaceFirst('FormatException: ', '')
              .replaceFirst('Error: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectProfile(int index) {
    setState(() {
      _selectedProfileIndex = index;
      _confirmed = false;
      _error = null;
    });
  }

  void _setManualMode(_ManualValueMode mode) {
    setState(() {
      _manualMode = _manualMode == mode ? _ManualValueMode.none : mode;
      _confirmed = false;
    });
  }

  void _addManualValue(TapDownDetails details, BoxConstraints constraints) {
    if (_manualMode == _ManualValueMode.none) return;
    final x = (details.localPosition.dx / constraints.maxWidth)
        .clamp(0.0, 1.0)
        .toDouble();
    final y = (details.localPosition.dy / constraints.maxHeight)
        .clamp(0.0, 1.0)
        .toDouble();
    final kind = switch (_manualMode) {
      _ManualValueMode.angle => ImageGeometryValueKind.angle,
      _ManualValueMode.chamfer => ImageGeometryValueKind.chamfer,
      _ => ImageGeometryValueKind.linear,
    };
    final reading = ImageDimensionReading(
      value: '',
      confidence: 100,
      x: x,
      y: y,
      vertical: _manualMode == _ManualValueMode.vertical,
      kind: kind,
    );
    setState(() {
      _readings.add(reading);
      _valueControllers.add(_newController(''));
      _manualMode = _ManualValueMode.none;
      _confirmed = false;
      _error = null;
    });
  }

  void _removeValue(int index) {
    if (index < 0 || index >= _readings.length) return;
    final controller = _valueControllers[index];
    setState(() {
      _readings.removeAt(index);
      _valueControllers.removeAt(index);
      _confirmed = false;
      _error = null;
    });
    controller.dispose();
  }

  Future<void> _download() async {
    final profile = _rebuiltProfile;
    if (profile == null || !_confirmed) return;
    final dxf = _buildDxf(profile.points);
    await downloadBytes(
      bytes: Uint8List.fromList(utf8.encode(dxf)),
      fileName: '${_outputBaseName}_EDITABLE_ANGLES_CHAMFER.dxf',
      mimeType: 'application/dxf;charset=utf-8',
    );
  }

  String _buildDxf(List<PdfProfilePoint> points) {
    final rows = <String>[
      '0',
      'SECTION',
      '2',
      'HEADER',
      '9',
      r'$INSUNITS',
      '70',
      '4',
      '0',
      'ENDSEC',
      '0',
      'SECTION',
      '2',
      'ENTITIES',
      '0',
      'LWPOLYLINE',
      '100',
      'AcDbEntity',
      '8',
      'OUTLINE',
      '100',
      'AcDbPolyline',
      '90',
      '${points.length}',
      '70',
      '1',
    ];
    for (final point in points) {
      rows
        ..add('10')
        ..add(point.x.toStringAsFixed(4))
        ..add('20')
        ..add(point.y.toStringAsFixed(4));
    }
    rows
      ..add('0')
      ..add('ENDSEC')
      ..add('0')
      ..add('EOF');
    return '${rows.join('\n')}\n';
  }

  @override
  Widget build(BuildContext context) {
    final rebuilt = _rebuiltProfile;
    return ColoredBox(
      color: AppColors.offWhite,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'PDF / Image → Editable DXF',
              subtitle:
                  'عدّل الأبعاد والزوايا كقيم رقمية، وأضف قيمة الشنفر عند الركن المطلوب. كل القيم تدخل فعليًا في هندسة DXF.',
              actions: [
                FilledButton.icon(
                  onPressed: _busy ? null : _pickAndAnalyze,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(_busy ? 'جاري التحليل…' : 'رفع PDF أو صورة'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _uploadCard(),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.warning),
                ),
              ),
            ],
            if (_analysis != null && _previewBytes != null) ...[
              const SizedBox(height: 16),
              if (_analysis!.profiles.length > 1) _profileSelector(),
              if (_analysis!.profiles.length > 1) const SizedBox(height: 16),
              AppCard(
                title: 'تحرير الأبعاد والزوايا والشنفر فوق الرسم',
                child: _valueEditor(),
              ),
              const SizedBox(height: 16),
              AppCard(
                title: 'المحيط النهائي المحسوب',
                child: rebuilt == null
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'أدخل بُعدًا صحيحًا واحدًا على الأقل بالملم. بعدها يمكن تطبيق الزوايا والشنفر على المحيط.',
                          style: TextStyle(color: AppColors.error),
                        ),
                      )
                    : _verificationPanel(rebuilt),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _uploadCard() {
    return AppCard(
      title: 'ملف الرسم',
      child: InkWell(
        onTap: _busy ? null : _pickAndAnalyze,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 145,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFB8C2D8), width: 2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.document_scanner_outlined,
                size: 38,
                color: AppColors.darkBlue,
              ),
              const SizedBox(height: 9),
              Text(
                _sourceFile?.fileName ?? 'اضغط لرفع PDF أو صورة الرسم',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'يقرأ الأبعاد، والزوايا المكتوبة بعلامة °، والشنفر بصيغة C2 أو CHAMFER 2 أو 2×45°.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileSelector() {
    final profiles = _analysis!.profiles;
    return AppCard(
      title: 'اختر محيط القطعة الصحيح',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: List<Widget>.generate(profiles.length, (index) {
          final selected = index == _selectedProfileIndex;
          final profile = profiles[index];
          return InkWell(
            onTap: () => _selectProfile(index),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.darkBlue.withValues(alpha: .07)
                    : Colors.white,
                border: Border.all(
                  color: selected
                      ? AppColors.darkBlue
                      : const Color(0xFFD5DBE8),
                  width: selected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 115,
                    child: CustomPaint(painter: _ProfilePainter(profile)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'محيط ${index + 1} • ${profile.vertexCount} نقطة',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
