part of 'image_to_dxf_screen.dart';

extension _ImageToDxfVerification on _ImageToDxfScreenState {
  Widget _verificationPanel(PdfProfileCandidate profile) {
    final angleValues = <String>[];
    final chamferValues = <String>[];
    final values = _values;
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value == null || !value.isFinite || value <= 0) continue;
      if (_readings[index].isAngle && value < 180) {
        angleValues.add('${_cleanNumber(value)}°');
      } else if (_readings[index].isChamfer) {
        chamferValues.add('${_cleanNumber(value)} mm');
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        final preview = SizedBox(
          height: 360,
          child: CustomPaint(
            painter: _ProfilePainter(profile, showVertices: true),
          ),
        );
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _metric('عدد نقاط DXF', '${profile.vertexCount}'),
            _metric('العرض النهائي', '${profile.width.toStringAsFixed(3)} mm'),
            _metric('الارتفاع النهائي', '${profile.height.toStringAsFixed(3)} mm'),
            _metric('الزوايا المطبقة', '${angleValues.length}'),
            _metric('الشنفر المطبق', '${chamferValues.length}'),
            if (angleValues.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'قيم الزوايا: ${angleValues.join(' • ')}',
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            if (chamferValues.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'قيم الشنفر: ${chamferValues.join(' • ')}',
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'ملف DXF مغلق وبوحدة mm. الزوايا والشنفر الظاهرة في المعاينة هي نفسها المكتوبة في الملف.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              onChanged: (value) {
                setState(() => _confirmed = value ?? false);
              },
              title: const Text(
                'تأكدت أن المحيط والأبعاد والزوايا والشنفر صحيحة',
              ),
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

  String _cleanNumber(double value) {
    return value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

class _ProfilePainter extends CustomPainter {
  const _ProfilePainter(this.profile, {this.showVertices = false});

  final PdfProfileCandidate profile;
  final bool showVertices;

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.points.length < 2) return;
    final scale = math.min(
      (size.width - 42) / math.max(1, profile.width),
      (size.height - 42) / math.max(1, profile.height),
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
        ..strokeWidth = 2.2,
    );

    if (!showVertices) return;
    final pointPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.fill;
    for (var index = 0; index < profile.points.length; index++) {
      final position = map(profile.points[index]);
      canvas.drawCircle(position, 3.5, pointPaint);
      if (profile.points.length <= 30) {
        final painter = TextPainter(
          text: TextSpan(
            text: '${index + 1}',
            style: const TextStyle(
              color: Color(0xFF991B1B),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, position + const Offset(5, -14));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ProfilePainter oldDelegate) {
    return oldDelegate.profile != profile ||
        oldDelegate.showVertices != showVertices;
  }
}
