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

enum _ManualDimensionMode { none, horizontal, vertical }

class ImageToDxfScreen extends StatefulWidget {
  const ImageToDxfScreen({super.key});

  @override
  State<ImageToDxfScreen> createState() => _ImageToDxfScreenState();
}

class _ImageToDxfScreenState extends State<ImageToDxfScreen> {
  final List<TextEditingController> _dimensionControllers = [];
  final List<ImageDimensionReading> _readings = [];

  PickedFile? _sourceFile;
  Uint8List? _previewBytes;
  PdfProfileAnalysis? _analysis;
  int _selectedProfileIndex = 0;
  bool _busy = false;
  bool _confirmed = false;
  String? _error;
  String _outputBaseName = 'DRAWING';
  _ManualDimensionMode _manualMode = _ManualDimensionMode.none;

  PdfProfileCandidate? get _baseProfile {
    final profiles = _analysis?.profiles;
    if (profiles == null || profiles.isEmpty) return null;
    final index = _selectedProfileIndex.clamp(0, profiles.length - 1).toInt();
    return profiles[index];
  }

  PdfProfileCandidate? get _rebuiltProfile {
    final base = _baseProfile;
    if (base == null) return null;
    final count = math.min(_readings.length, _dimensionControllers.length);
    return ImageDimensionGeometry.rebuild(
      base: base,
      readings: _readings.take(count).toList(growable: false),
      values: List<double?>.generate(
        count,
        (index) => double.tryParse(
          _dimensionControllers[index].text.trim().replaceAll(',', '.'),
        ),
        growable: false,
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _dimensionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _newController(String value) {
    final controller = TextEditingController(text: value);
    controller.addListener(_dimensionChanged);
    return controller;
  }

  void _setDimensionReadings(List<ImageDimensionReading> readings) {
    for (final controller in _dimensionControllers) {
      controller.dispose();
    }
    _dimensionControllers
      ..clear()
      ..addAll(readings.map((reading) => _newController(reading.value)));
    _readings
      ..clear()
      ..addAll(readings);
  }

  void _dimensionChanged() {
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
      _manualMode = _ManualDimensionMode.none;
      _error = null;
      _outputBaseName = file.fileName.replaceAll(
        RegExp(r'\.(pdf|png|jpe?g|webp)$', caseSensitive: false),
        '',
      );
      _setDimensionReadings(const []);
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
          'لم يتم العثور على محيط مغلق واضح. اختر محيطًا أوضح أو قص الصفحة حول الرسمة.',
        );
      }
      if (!mounted) return;
      setState(() {
        _previewBytes = preview;
        _analysis = analysis;
        _selectedProfileIndex = 0;
        _setDimensionReadings(analysis.dimensionReadings);
        if (analysis.dimensionReadings.isEmpty) {
          _error =
              'لم تُقرأ الأرقام تلقائيًا. استخدم إضافة بُعد أفقي أو رأسي واضغط مكان الرقم على الرسمة.';
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

  void _setManualMode(_ManualDimensionMode mode) {
    setState(() {
      _manualMode = _manualMode == mode ? _ManualDimensionMode.none : mode;
      _confirmed = false;
    });
  }

  void _addManualDimension(TapDownDetails details, BoxConstraints constraints) {
    if (_manualMode == _ManualDimensionMode.none) return;
    final x = (details.localPosition.dx / constraints.maxWidth)
        .clamp(0.0, 1.0)
        .toDouble();
    final y = (details.localPosition.dy / constraints.maxHeight)
        .clamp(0.0, 1.0)
        .toDouble();
    final reading = ImageDimensionReading(
      value: '',
      confidence: 100,
      x: x,
      y: y,
      vertical: _manualMode == _ManualDimensionMode.vertical,
    );
    setState(() {
      _readings.add(reading);
      _dimensionControllers.add(_newController(''));
      _manualMode = _ManualDimensionMode.none;
      _confirmed = false;
      _error = null;
    });
  }

  void _removeDimension(int index) {
    if (index < 0 || index >= _readings.length) return;
    final controller = _dimensionControllers[index];
    setState(() {
      _readings.removeAt(index);
      _dimensionControllers.removeAt(index);
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
      fileName: '${_outputBaseName}_EDITABLE_DIMENSIONS.dxf',
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
                  'ارفع PDF أو صورة، عدّل جميع قيم mm فوق الرسم، وأضف أي قيمة لم تُقرأ يدويًا في مكانها.',
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
                title: 'كل الأبعاد قابلة للتحرير فوق الرسم',
                child: _dimensionEditor(),
              ),
              const SizedBox(height: 16),
              AppCard(
                title: 'المحيط النهائي المحسوب',
                child: rebuilt == null
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'أدخل قيمة صحيحة لواحد أو أكثر من الأبعاد، واحذف القراءات الخاطئة أو اختر المحيط الصحيح.',
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
                'الصفحة الأولى من PDF تتحول تلقائيًا إلى محرر أبعاد كامل.',
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

  Widget _dimensionEditor() {
    final analysis = _analysis!;
    final width = analysis.sourceImageWidth;
    final height = analysis.sourceImageHeight;
    final aspectRatio = width > 0 && height > 0 ? width / height : 1.4;
    final adding = _manualMode != _ManualDimensionMode.none;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'القيم الموجودة: ${_readings.length}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  _setManualMode(_ManualDimensionMode.horizontal),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('إضافة بُعد أفقي'),
              style: _manualMode == _ManualDimensionMode.horizontal
                  ? OutlinedButton.styleFrom(
                      backgroundColor:
                          AppColors.darkBlue.withValues(alpha: .09),
                    )
                  : null,
            ),
            OutlinedButton.icon(
              onPressed: () => _setManualMode(_ManualDimensionMode.vertical),
              icon: const Icon(Icons.swap_vert),
              label: const Text('إضافة بُعد رأسي'),
              style: _manualMode == _ManualDimensionMode.vertical
                  ? OutlinedButton.styleFrom(
                      backgroundColor:
                          AppColors.darkBlue.withValues(alpha: .09),
                    )
                  : null,
            ),
            if (adding)
              const Text(
                'اضغط الآن على مكان الرقم داخل الرسم.',
                style: TextStyle(
                  color: AppColors.info,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'عدّل أي رقم مباشرة. استخدم × لحذف قراءة خاطئة. لا يتم إنشاء أي رقم من عند النظام.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1150),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: adding
                            ? (details) => _addManualDimension(
                                  details,
                                  constraints,
                                )
                            : null,
                        child: Image.memory(
                          _previewBytes!,
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                        ),
                      ),
                      ...List<Widget>.generate(
                        math.min(
                          _readings.length,
                          _dimensionControllers.length,
                        ),
                        (index) => _dimensionField(
                          index,
                          _readings[index],
                          _dimensionControllers[index],
                          constraints,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dimensionField(
    int index,
    ImageDimensionReading reading,
    TextEditingController controller,
    BoxConstraints constraints,
  ) {
    final editorWidth = reading.vertical ? 46.0 : 108.0;
    final editorHeight = reading.vertical ? 108.0 : 46.0;
    final left = (reading.x * constraints.maxWidth - editorWidth / 2)
        .clamp(0.0, math.max(0.0, constraints.maxWidth - editorWidth))
        .toDouble();
    final top = (reading.y * constraints.maxHeight - editorHeight / 2)
        .clamp(0.0, math.max(0.0, constraints.maxHeight - editorHeight))
        .toDouble();

    Widget field = SizedBox(
      width: 100,
      height: 40,
      child: TextField(
        controller: controller,
        autofocus: controller.text.isEmpty,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          suffixText: 'mm',
          hintText: 'القيمة',
          fillColor: Colors.white.withValues(alpha: .96),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
          border: const OutlineInputBorder(),
        ),
      ),
    );
    if (reading.vertical) {
      field = RotatedBox(quarterTurns: 3, child: field);
    }

    return Positioned(
      left: left,
      top: top,
      width: editorWidth,
      height: editorHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: Center(child: field)),
          Positioned(
            top: -5,
            right: -5,
            child: Material(
              color: AppColors.error,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _removeDimension(index),
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verificationPanel(PdfProfileCandidate profile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        final preview = SizedBox(
          height: 340,
          child: CustomPaint(painter: _ProfilePainter(profile)),
        );
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _metric('عدد نقاط المحيط', '${profile.vertexCount}'),
            _metric('العرض النهائي', '${profile.width.toStringAsFixed(3)} mm'),
            _metric('الارتفاع النهائي', '${profile.height.toStringAsFixed(3)} mm'),
            const SizedBox(height: 10),
            const Text(
              'الناتج DXF مغلق، بوحدة mm، ويحتوي على محيط القطعة فقط.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              onChanged: (value) {
                setState(() => _confirmed = value ?? false);
              },
              title: const Text('تأكدت أن المحيط وجميع قيم mm صحيحة'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _confirmed ? _download : null,
              icon: const Icon(Icons.download),
              label: const Text('تحميل DXF النهائي'),
            ),
          ],
        );
        return compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [preview, const SizedBox(height: 18), details],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: preview),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: details),
                ],
              );
      },
    );
  }

  Widget _metric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ProfilePainter extends CustomPainter {
  const _ProfilePainter(this.profile);

  final PdfProfileCandidate profile;

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.points.length < 2) return;
    final scale = math.min(
      (size.width - 28) / math.max(1, profile.width),
      (size.height - 28) / math.max(1, profile.height),
    ).toDouble();
    final left = (size.width - profile.width * scale) / 2;
    final bottom = (size.height - profile.height * scale) / 2;
    Offset map(PdfProfilePoint point) => Offset(
          left + point.x * scale,
          size.height - bottom - point.y * scale,
        );

    final path = Path();
    final first = map(profile.points.first);
    path.moveTo(first.dx, first.dy);
    for (final point in profile.points.skip(1)) {
      final offset = map(point);
      path.lineTo(offset.dx, offset.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.darkBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ProfilePainter oldDelegate) {
    return oldDelegate.profile != profile;
  }
}
