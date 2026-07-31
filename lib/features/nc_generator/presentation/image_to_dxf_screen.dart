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

class ImageToDxfScreen extends StatefulWidget {
  const ImageToDxfScreen({super.key});

  @override
  State<ImageToDxfScreen> createState() => _ImageToDxfScreenState();
}

class _ImageToDxfScreenState extends State<ImageToDxfScreen> {
  final List<TextEditingController> _dimensionControllers = [];

  PickedFile? _image;
  PdfProfileAnalysis? _analysis;
  int _selectedProfileIndex = 0;
  bool _busy = false;
  bool _confirmed = false;
  String? _error;
  String _outputBaseName = 'DRAWING';

  PdfProfileCandidate? get _baseProfile {
    final profiles = _analysis?.profiles;
    if (profiles == null || profiles.isEmpty) return null;
    final index = _selectedProfileIndex.clamp(0, profiles.length - 1).toInt();
    return profiles[index];
  }

  PdfProfileCandidate? get _rebuiltProfile {
    final analysis = _analysis;
    final base = _baseProfile;
    if (analysis == null || base == null) return null;
    final count = math.min(
      analysis.dimensionReadings.length,
      _dimensionControllers.length,
    );
    return ImageDimensionGeometry.rebuild(
      base: base,
      readings: analysis.dimensionReadings.take(count).toList(growable: false),
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

  void _setDimensionReadings(List<ImageDimensionReading> readings) {
    for (final controller in _dimensionControllers) {
      controller.dispose();
    }
    _dimensionControllers
      ..clear()
      ..addAll(
        readings.map((reading) {
          final controller = TextEditingController(text: reading.value);
          controller.addListener(_dimensionChanged);
          return controller;
        }),
      );
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
      extensions: const ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (files.isEmpty || !mounted) return;
    final file = files.first;
    setState(() {
      _image = file;
      _analysis = null;
      _selectedProfileIndex = 0;
      _busy = true;
      _confirmed = false;
      _error = null;
      _outputBaseName = file.fileName.replaceAll(
        RegExp(r'\.(png|jpe?g|webp)$', caseSensitive: false),
        '',
      );
      _setDimensionReadings(const []);
    });

    try {
      final analysis = await analyzeDrawingImage(
        bytes: file.bytes,
        contentType: file.contentType,
      );
      if (analysis.profiles.isEmpty) {
        throw const FormatException(
          'لم يتم العثور على محيط مغلق واضح في الصورة. قص الصورة على الرسمة فقط ثم أعد المحاولة.',
        );
      }
      if (analysis.dimensionReadings.isEmpty) {
        throw const FormatException(
          'تم العثور على المحيط، لكن لم تُقرأ أي أرقام أبعاد مكتوبة.',
        );
      }
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _selectedProfileIndex = 0;
        _setDimensionReadings(analysis.dimensionReadings);
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
              title: 'Image → Exact Editable DXF',
              subtitle:
                  'ارفع أي رسمة مغلقة؛ تُقرأ الأبعاد المكتوبة وتبقى قابلة للتعديل في مواقعها، ثم يُعاد حساب المحيط بوحدة mm.',
              actions: [
                FilledButton.icon(
                  onPressed: _busy ? null : _pickAndAnalyze,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(_busy ? 'جاري التحليل…' : 'رفع صورة'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _uploadCard(),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
            if (_analysis != null && _image != null) ...[
              const SizedBox(height: 16),
              if (_analysis!.profiles.length > 1) _profileSelector(),
              if (_analysis!.profiles.length > 1) const SizedBox(height: 16),
              AppCard(
                title: 'الأبعاد القابلة للتعديل داخل الرسمة',
                child: _dimensionEditor(),
              ),
              const SizedBox(height: 16),
              AppCard(
                title: 'المحيط المحسوب النهائي',
                child: rebuilt == null
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'تعذر ربط الأبعاد بالمحيط. صحح الأرقام غير المقروءة أو اختر المحيط الصحيح أعلاه.',
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
      title: 'صورة الرسم',
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
                Icons.image_search_outlined,
                size: 38,
                color: AppColors.darkBlue,
              ),
              const SizedBox(height: 9),
              Text(
                _image?.fileName ?? 'اضغط لرفع صورة أو قصاصة واضحة',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'لا تُضاف أبعاد غير مكتوبة، ولا يُفترض شكل ثابت.',
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
      title: 'اختر المحيط الصحيح',
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
                    child: CustomPaint(
                      painter: _ProfilePainter(profile),
                      size: const Size(double.infinity, 115),
                    ),
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
    final image = _image!;
    final analysis = _analysis!;
    final width = analysis.sourceImageWidth;
    final height = analysis.sourceImageHeight;
    final aspectRatio = width > 0 && height > 0 ? width / height : 1.4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'تمت قراءة ${_dimensionControllers.length} قيمة. اضغط على أي قيمة وعدلها وهي في مكانها.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        image.bytes,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                      ),
                      ...List<Widget>.generate(
                        math.min(
                          analysis.dimensionReadings.length,
                          _dimensionControllers.length,
                        ),
                        (index) => _dimensionField(
                          analysis.dimensionReadings[index],
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
    ImageDimensionReading reading,
    TextEditingController controller,
    BoxConstraints constraints,
  ) {
    final editorWidth = reading.vertical ? 40.0 : 96.0;
    final editorHeight = reading.vertical ? 96.0 : 40.0;
    final left = (reading.x * constraints.maxWidth - editorWidth / 2)
        .clamp(0.0, math.max(0.0, constraints.maxWidth - editorWidth))
        .toDouble();
    final top = (reading.y * constraints.maxHeight - editorHeight / 2)
        .clamp(0.0, math.max(0.0, constraints.maxHeight - editorHeight))
        .toDouble();
    Widget editor = SizedBox(
      width: 96,
      height: 40,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          suffixText: 'mm',
          fillColor: Colors.white.withValues(alpha: .95),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
          border: const OutlineInputBorder(),
        ),
      ),
    );
    if (reading.vertical) {
      editor = RotatedBox(quarterTurns: 3, child: editor);
    }
    return Positioned(
      left: left,
      top: top,
      width: editorWidth,
      height: editorHeight,
      child: editor,
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
              'يُنشأ DXF مغلق بوحدة الملليمتر من المحيط المكتشف وجميع القيم المعدلة.',
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
              label: const Text('تحميل DXF المحسوب'),
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
