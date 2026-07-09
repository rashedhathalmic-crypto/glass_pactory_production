import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'illustration_paint_helpers.dart';

class GrindingWashingDepartmentIllustration extends StatelessWidget {
  const GrindingWashingDepartmentIllustration({super.key});

  static const double preferredHeight = 180;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _GrindingWashingPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _GrindingWashingPainter extends CustomPainter {
  const _GrindingWashingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final floorY = h * 0.82;

    IllustrationPaintHelpers.paintBackground(canvas, size);
    IllustrationPaintHelpers.paintFloor(canvas, w, floorY);

    _paintWashingUnit(canvas, w * 0.14, h * 0.38, w * 0.34, floorY);
    _paintGrindingStation(canvas, w * 0.56, h * 0.42, w * 0.32, floorY);
    _paintWaterSystem(canvas, w * 0.78, h * 0.28, floorY);
    IllustrationPaintHelpers.paintGlassSheet(
      canvas,
      Rect.fromLTWH(w * 0.22, h * 0.58, w * 0.22, 14),
    );
  }

  void _paintWashingUnit(
    Canvas canvas,
    double left,
    double top,
    double width,
    double floorY,
  ) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, floorY - top - 8),
      const Radius.circular(6),
    );
    canvas.drawRRect(body, IllustrationPaintHelpers.fill(const Color(0xFFD5DCE8)));
    canvas.drawRRect(body, IllustrationPaintHelpers.stroke(AppColors.darkBlueMuted.withValues(alpha: 0.2)));

    final drum = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(left + width * 0.5, top + 34),
        width: width * 0.55,
        height: 42,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(drum, IllustrationPaintHelpers.fill(AppColors.darkBlueLight));
    canvas.drawRRect(drum, IllustrationPaintHelpers.stroke(AppColors.darkBlue, width: 1.2));

    for (var i = 0; i < 3; i++) {
      final y = top + 52 + i * 6;
      canvas.drawLine(
        Offset(left + 16, y),
        Offset(left + width - 16, y),
        IllustrationPaintHelpers.stroke(AppColors.info.withValues(alpha: 0.35), width: 1.5),
      );
    }
  }

  void _paintGrindingStation(
    Canvas canvas,
    double left,
    double top,
    double width,
    double floorY,
  ) {
    final base = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top + 20, width, floorY - top - 24),
      const Radius.circular(5),
    );
    canvas.drawRRect(base, IllustrationPaintHelpers.fill(const Color(0xFFC8D0DC)));

    final wheelCenter = Offset(left + width * 0.35, top + 36);
    canvas.drawCircle(
      wheelCenter,
      22,
      IllustrationPaintHelpers.fill(AppColors.mediumGray),
    );
    canvas.drawCircle(
      wheelCenter,
      22,
      IllustrationPaintHelpers.stroke(AppColors.darkBlueMuted, width: 2),
    );
    canvas.drawCircle(
      wheelCenter,
      8,
      IllustrationPaintHelpers.fill(AppColors.darkBlue),
    );

    final wheel2 = Offset(left + width * 0.72, top + 48);
    canvas.drawCircle(wheel2, 16, IllustrationPaintHelpers.fill(AppColors.mediumGray));
    canvas.drawCircle(wheel2, 16, IllustrationPaintHelpers.stroke(AppColors.darkBlueMuted, width: 1.5));

    canvas.drawRect(
      Rect.fromLTWH(left + 8, top + 8, width - 16, 8),
      IllustrationPaintHelpers.fill(AppColors.darkBlue),
    );
  }

  void _paintWaterSystem(Canvas canvas, double left, double top, double floorY) {
    final tank = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top + 30, 36, floorY - top - 36),
      const Radius.circular(4),
    );
    canvas.drawRRect(tank, IllustrationPaintHelpers.fill(AppColors.infoBg));
    canvas.drawRRect(tank, IllustrationPaintHelpers.stroke(AppColors.info.withValues(alpha: 0.4)));

    final pipe = Paint()
      ..color = AppColors.info
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(left - 18, top + 48), Offset(left, top + 48), pipe);
    canvas.drawLine(Offset(left + 18, top + 70), Offset(left - 30, top + 70), pipe);

    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(left + 10 + i * 5, top + 52 + i * 8),
        2,
        IllustrationPaintHelpers.fill(AppColors.info.withValues(alpha: 0.5)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
