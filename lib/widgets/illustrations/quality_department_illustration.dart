import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'illustration_paint_helpers.dart';

class QualityDepartmentIllustration extends StatelessWidget {
  const QualityDepartmentIllustration({super.key});

  static const double preferredHeight = 180;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _QualityDepartmentPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _QualityDepartmentPainter extends CustomPainter {
  const _QualityDepartmentPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final floorY = h * 0.82;

    IllustrationPaintHelpers.paintBackground(canvas, size);
    IllustrationPaintHelpers.paintFloor(canvas, w, floorY);

    _paintInspectionStation(canvas, w * 0.12, h * 0.42, w * 0.5, floorY);
    _paintInspector(canvas, w * 0.62, h * 0.34, floorY);
    _paintMeasuringTools(canvas, w * 0.72, h * 0.58);
    IllustrationPaintHelpers.paintGlassSheet(
      canvas,
      Rect.fromLTWH(w * 0.2, h * 0.6, w * 0.28, 12),
    );
  }

  void _paintInspectionStation(
    Canvas canvas,
    double left,
    double top,
    double width,
    double floorY,
  ) {
    final table = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top + 28, width, floorY - top - 34),
      const Radius.circular(4),
    );
    canvas.drawRRect(table, IllustrationPaintHelpers.fill(const Color(0xFFD5DCE8)));
    canvas.drawRRect(table, IllustrationPaintHelpers.stroke(AppColors.border));

    final surface = RRect.fromRectAndRadius(
      Rect.fromLTWH(left + 8, top + 8, width - 16, 22),
      const Radius.circular(2),
    );
    canvas.drawRRect(surface, IllustrationPaintHelpers.fill(AppColors.white));
    canvas.drawRRect(surface, IllustrationPaintHelpers.stroke(AppColors.darkBlueMuted.withValues(alpha: 0.2)));

    final lamp = RRect.fromRectAndRadius(
      Rect.fromLTWH(left + width * 0.35, top - 18, width * 0.3, 14),
      const Radius.circular(3),
    );
    canvas.drawRRect(lamp, IllustrationPaintHelpers.fill(AppColors.darkBlue));
    canvas.drawRect(
      Rect.fromLTWH(left + width * 0.38, top - 4, width * 0.24, 6),
      IllustrationPaintHelpers.fill(AppColors.warningBg),
    );
  }

  void _paintInspector(Canvas canvas, double left, double top, double floorY) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top + 36, 28, floorY - top - 42),
      const Radius.circular(6),
    );
    canvas.drawRRect(body, IllustrationPaintHelpers.fill(AppColors.darkBlueLight));

    canvas.drawCircle(
      Offset(left + 14, top + 18),
      12,
      IllustrationPaintHelpers.fill(const Color(0xFFE8C4A8)),
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(left + 14, top + 10), width: 26, height: 18),
      3.14,
      3.14,
      false,
      IllustrationPaintHelpers.stroke(AppColors.darkBlue, width: 3),
    );

    canvas.drawRect(
      Rect.fromLTWH(left + 30, top + 44, 22, 4),
      IllustrationPaintHelpers.fill(AppColors.info),
    );
  }

  void _paintMeasuringTools(Canvas canvas, double left, double top) {
    canvas.drawRect(
      Rect.fromLTWH(left, top, 34, 6),
      IllustrationPaintHelpers.fill(AppColors.darkBlue),
    );
    for (var i = 0; i < 6; i++) {
      canvas.drawLine(
        Offset(left + 4 + i * 5, top),
        Offset(left + 4 + i * 5, top + 10),
        IllustrationPaintHelpers.stroke(AppColors.darkBlueMuted, width: 1),
      );
    }

    final caliper = Path()
      ..moveTo(left + 4, top + 24)
      ..lineTo(left + 30, top + 24)
      ..lineTo(left + 26, top + 34)
      ..lineTo(left + 8, top + 34)
      ..close();
    canvas.drawPath(caliper, IllustrationPaintHelpers.fill(AppColors.mediumGray));
    canvas.drawPath(caliper, IllustrationPaintHelpers.stroke(AppColors.darkBlue, width: 1));

    canvas.drawCircle(
      Offset(left + 42, top + 18),
      8,
      IllustrationPaintHelpers.stroke(AppColors.success, width: 2),
    );
    canvas.drawLine(
      Offset(left + 42, top + 10),
      Offset(left + 42, top + 26),
      IllustrationPaintHelpers.stroke(AppColors.success, width: 1.5),
    );
    canvas.drawLine(
      Offset(left + 34, top + 18),
      Offset(left + 50, top + 18),
      IllustrationPaintHelpers.stroke(AppColors.success, width: 1.5),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
