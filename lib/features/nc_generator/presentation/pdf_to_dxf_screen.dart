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

class PdfToDxfScreen extends StatefulWidget {
  const PdfToDxfScreen({super.key});

  @override
  State<PdfToDxfScreen> createState() => _PdfToDxfScreenState();
}

class _PdfToDxfScreenState extends State<PdfToDxfScreen> {
  final _actualWidth = TextEditingController();

  PickedFile? _pdf;
  PdfProfileAnalysis? _analysis;
  int _selectedIndex = 0;
  String? _error;
  String _outputBaseName = 'PASTED_DRAWING';
  bool _busy = false;
  bool _dimensionsConfirmed = false;

  PdfProfileCandidate? get _selected {
    final profiles = _analysis?.profiles;
    if (profiles == null || profiles.isEmpty) return null;
    return profiles[_selectedIndex.clamp(0, profiles.length - 1).toInt()];
  }

  double get _targetWidth {
    final selected = _selected;
    if (selected == null) return 0;
    final entered = double.tryParse(_actualWidth.text.replaceAll(',', '.'));
    if (entered != null) return entered;
    return _analysis?.isClipboardImage ?? false ? 0 : selected.width;
  }

  double get _uniformScale {
    final selected = _selected;
    if (selected == null || selected.width <= 0) return 1;
    return _targetWidth / selected.width;
  }

  double get _targetHeight => (_selected?.height ?? 0) * _uniformScale;

  @override
  void initState() {
    super.initState();
    _actualWidth.addListener(_widthChanged);
  }

  @override
  void dispose() {
    _actualWidth
      ..removeListener(_widthChanged)
      ..dispose();
    super.dispose();
  }

  void _widthChanged() {
    if (!mounted || _analysis == null) return;
    setState(() => _dimensionsConfirmed = false);
  }

  Future<void> _pickAndAnalyze() async {
    final files = await pickFiles(extensions: const ['pdf']);
    if (files.isEmpty || !mounted) return;

    setState(() {
      _pdf = files.first;
      _analysis = null;
      _selectedIndex = 0;
      _busy = true;
      _error = null;
      _dimensionsConfirmed = false;
      _outputBaseName = files.first.fileName.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );
    });

    try {
      final analysis = await analyzePdfProfiles(bytes: _pdf!.bytes);
      if (analysis.profiles.isEmpty) {
        throw const FormatException(
          'لم يتم العثور على مسقط ثنائي صالح داخل ملف PDF.',
        );
      }
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _selectedIndex = 0;
        _actualWidth.text = analysis.profiles.first.width.toStringAsFixed(3);
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

  Future<void> _pasteAndAnalyze() async {
    setState(() {
      _pdf = null;
      _analysis = null;
      _selectedIndex = 0;
      _busy = true;
      _error = null;
      _outputBaseName = 'PASTED_DRAWING';
      _dimensionsConfirmed = false;
    });

    try {
      final analysis = await analyzeClipboardDrawing();
      if (analysis.profiles.isEmpty) {
        throw const FormatException(
          'لم يتم العثور على رسم ثنائي مغلق في الصورة المنسوخة.',
        );
      }
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _selectedIndex = 0;
        _actualWidth.clear();
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
    final profile = _analysis!.profiles[index];
    setState(() {
      _selectedIndex = index;
      _dimensionsConfirmed = false;
      _error = null;
      _actualWidth.text = _analysis!.isClipboardImage
          ? ''
          : profile.width.toStringAsFixed(3);
    });
  }

  Future<void> _downloadSelected() async {
    final selected = _selected;
    if (selected == null || !_dimensionsConfirmed) return;
    if (!(_targetWidth > 0) || !(_targetHeight > 0)) {
      setState(() => _error = 'أدخل عرضًا صحيحًا أكبر من صفر.');
      return;
    }

    final points = selected.points
        .map(
          (point) => PdfProfilePoint(
            point.x * _uniformScale,
            point.y * _uniformScale,
          ),
        )
        .toList(growable: false);
    final output = _buildDxf(points);
    await downloadBytes(
      bytes: Uint8List.fromList(utf8.encode(output)),
      fileName: '${_outputBaseName}_PROFILE_ONLY.dxf',
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

  List<double> _cornerAngles(PdfProfileCandidate profile) {
    final points = profile.points;
    if (points.length < 3) return const [];
    return List<double>.generate(points.length, (index) {
      final previous = points[(index - 1 + points.length) % points.length];
      final current = points[index];
      final next = points[(index + 1) % points.length];
      final ax = previous.x - current.x;
      final ay = previous.y - current.y;
      final bx = next.x - current.x;
      final by = next.y - current.y;
      final denominator =
          math.sqrt(ax * ax + ay * ay) * math.sqrt(bx * bx + by * by);
      if (denominator == 0) return 0;
      final cosine = ((ax * bx + ay * by) / denominator).clamp(-1.0, 1.0);
      return math.acos(cosine) * 180 / math.pi;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.offWhite,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'PDF → DXF 2D — Verified Profile',
              subtitle:
                  'الصق الرسمة المحددة أو ارفع PDF، ثم راجع الطول والعرض والزوايا وحمّل DXF.',
              actions: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pasteAndAnalyze,
                  icon: const Icon(Icons.content_paste),
                  label: const Text('لصق الرسمة'),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _pickAndAnalyze,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf),
                  label: Text(_busy ? 'جاري التحليل…' : 'رفع وتحليل PDF'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AppCard(
              title: 'لصق الرسمة مباشرة',
              child: InkWell(
                onTap: _busy ? null : _pasteAndAnalyze,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 150,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFFB8C2D8),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.content_paste_go,
                        size: 38,
                        color: AppColors.darkBlue,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _busy
                            ? 'جاري استخراج الرسم…'
                            : 'انسخ الرسمة من PDF ثم اضغط هنا للصقها',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'بعد الاستخراج أدخل العرض الحقيقي بالملليمتر.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              title: '1 — تحليل الملف',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _analysis?.isClipboardImage ?? false
                        ? 'تم لصق الرسمة من الحافظة.'
                        : _pdf?.fileName ?? 'لم يتم رفع ملف PDF أو لصق رسمة.',
                  ),
                  if (_analysis != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _analysis!.isClipboardImage
                          ? 'عدد المحيطات المغلقة: ${_analysis!.profiles.length}'
                          : 'مقياس الرسم المكتشف: 1:${_analysis!.drawingScale.toStringAsFixed(_analysis!.drawingScale % 1 == 0 ? 0 : 2)}'
                              '  •  عدد المساقط المحتملة: ${_analysis!.profiles.length}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                ],
              ),
            ),
            if (_analysis != null) ...[
              const SizedBox(height: 16),
              AppCard(
                title: '2 — اختر المسقط الثنائي الكامل',
                child: _profileSelector(),
              ),
              const SizedBox(height: 16),
              AppCard(
                title: '3 — راجع الشكل والمقاسات والزوايا',
                child: _verificationPanel(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _profileSelector() {
    final profiles = _analysis!.profiles;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List<Widget>.generate(profiles.length, (index) {
        final profile = profiles[index];
        final selected = index == _selectedIndex;
        return InkWell(
          onTap: () => _selectProfile(index),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 230,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.darkBlue.withValues(alpha: .07)
                  : Colors.white,
              border: Border.all(
                color: selected ? AppColors.darkBlue : const Color(0xFFD5DBE8),
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'خيار ${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (profile.suggested)
                      const Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('مقترح'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 130,
                  child: CustomPaint(painter: _PdfProfilePainter(profile)),
                ),
                const SizedBox(height: 8),
                Text(
                  '${profile.width.toStringAsFixed(2)} × '
                  '${profile.height.toStringAsFixed(2)} '
                  '${_analysis!.isClipboardImage ? 'px' : 'mm'}',
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${profile.vertexCount} زوايا/نقاط',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _verificationPanel() {
    final profile = _selected!;
    final angles = _cornerAngles(profile);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 850;
        final preview = SizedBox(
          height: 340,
          child: CustomPaint(painter: _PdfProfilePainter(profile)),
        );
        final details = _profileDetails(profile, angles);
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

  Widget _profileDetails(
    PdfProfileCandidate profile,
    List<double> angles,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _metric(
          _analysis!.isClipboardImage ? 'عرض الصورة' : 'العرض المكتشف',
          '${profile.width.toStringAsFixed(3)} '
              '${_analysis!.isClipboardImage ? 'px' : 'mm'}',
        ),
        _metric(
          _analysis!.isClipboardImage ? 'ارتفاع الصورة' : 'الارتفاع المكتشف',
          '${profile.height.toStringAsFixed(3)} '
              '${_analysis!.isClipboardImage ? 'px' : 'mm'}',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _actualWidth,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'العرض الفعلي حسب أبعاد المخطط',
            suffixText: 'mm',
            helperText:
                'أدخل العرض الحقيقي؛ يُحسب الارتفاع بنفس النسبة وتُحفظ الزوايا.',
          ),
        ),
        const SizedBox(height: 12),
        _metric(
          'الارتفاع الناتج بعد التصحيح',
          '${_targetHeight.toStringAsFixed(3)} mm',
        ),
        const SizedBox(height: 14),
        const Text(
          'زوايا الأركان',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: List<Widget>.generate(
            angles.length,
            (index) => Chip(
              visualDensity: VisualDensity.compact,
              label: Text(
                '${index + 1}: ${angles[index].toStringAsFixed(2)}°',
              ),
            ),
          ),
        ),
        if (profile.inferredClosure) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5DB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'تنبيه: المخطط الأصلي يحتوي فجوة، وتم إغلاق الضلع بين أول وآخر نقطة. راجع المعاينة قبل الاعتماد.',
            ),
          ),
        ],
        const SizedBox(height: 14),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _dimensionsConfirmed,
          onChanged: (value) {
            setState(() => _dimensionsConfirmed = value ?? false);
          },
          title: const Text(
            'تأكدت أن هذا هو المسقط الكامل وأن المقاسات صحيحة',
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _dimensionsConfirmed ? _downloadSelected : null,
          icon: const Icon(Icons.download),
          label: const Text('تحميل الرسم المحدد DXF'),
        ),
      ],
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

class _PdfProfilePainter extends CustomPainter {
  const _PdfProfilePainter(this.profile);

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
  bool shouldRepaint(covariant _PdfProfilePainter oldDelegate) {
    return oldDelegate.profile != profile;
  }
}
