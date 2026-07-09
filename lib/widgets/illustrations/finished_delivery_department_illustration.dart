import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'illustration_paint_helpers.dart';

class FinishedDeliveryDepartmentIllustration extends StatelessWidget {
  const FinishedDeliveryDepartmentIllustration({super.key});

  static const double preferredHeight = 180;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _FinishedDeliveryPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _FinishedDeliveryPainter extends CustomPainter {
  const _FinishedDeliveryPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final floorY = h * 0.82;

    IllustrationPaintHelpers.paintBackground(canvas, size);
    IllustrationPaintHelpers.paintFloor(canvas, w, floorY);

    _paintCrate(canvas, w * 0.1, h * 0.48, w * 0.22, floorY);
    _paintPackedGlass(canvas, w * 0.14, h * 0.42, w * 0.14);
    _paintForklift(canvas, w * 0.4, h * 0.38, floorY);
    _paintTruck(canvas, w * 0.62, h * 0.36, w * 0.3, floorY);
  }

  void _paintCrate(
    Canvas canvas,
    double left,
    double top,
    double width,
    double floorY,
  ) {
    final crate = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, floorY - top - 6),
      const Radius.circular(3),
    );
    canvas.drawRRect(crate, IllustrationPaintHelpers.fill(const Color(0xFFC4A574)));
    canvas.drawRRect(crate, IllustrationPaintHelpers.stroke(const Color(0xFF8B6914), width: 1.2));

    for (var i = 1; i < 4; i++) {
      canvas.drawLine(
        Offset(left, top + i * (floorY - top - 6) / 4),
        Offset(left + width, top + i * (floorY - top - 6) / 4),
        IllustrationPaintHelpers.stroke(const Color(0xFF8B6914).withValues(alpha: 0.35), width: 1),
      );
      canvas.drawLine(
        Offset(left + i * width / 4, top),
        Offset(left + i * width / 4, floorY - 6),
        IllustrationPaintHelpers.stroke(const Color(0xFF8B6914).withValues(alpha: 0.35), width: 1),
      );
    }
  }

  void _paintPackedGlass(Canvas canvas, double left, double top, double width) {
    IllustrationPaintHelpers.paintGlassSheet(
      canvas,
      Rect.fromLTWH(left, top, width, 10),
    );
    canvas.drawRect(
      Rect.fromLTWH(left - 2, top - 4, width + 4, 4),
      IllustrationPaintHelpers.fill(AppColors.darkBlueMuted.withValues(alpha: 0.2)),
    );
  }

  void _paintForklift(Canvas canvas, double left, double top, double floorY) {
    final mast = Rect.fromLTWH(left + 18, top, 8, floorY - top - 18);
    canvas.drawRect(mast, IllustrationPaintHelpers.fill(AppColors.darkBlue));

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top + 38, 44, floorY - top - 44),
      const Radius.circular(3),
    );
    canvas.drawRRect(body, IllustrationPaintHelpers.fill(AppColors.warning));
    canvas.drawRRect(body, IllustrationPaintHelpers.stroke(const Color(0xFFB8860B), width: 1));

    final forks = Paint()
      ..color = AppColors.darkBlueMuted
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset(left + 26, top + 30), Offset(left + 50, top + 30), forks);
    canvas.drawLine(Offset(left + 26, top + 36), Offset(left + 50, top + 36), forks);

    canvas.drawCircle(
      Offset(left + 12, floorY - 8),
      6,
      IllustrationPaintHelpers.fill(AppColors.darkBlue),
    );
    canvas.drawCircle(
      Offset(left + 34, floorY - 8),
      6,
      IllustrationPaintHelpers.fill(AppColors.darkBlue),
    );
  }

  void _paintTruck(
    Canvas canvas,
    double left,
    double top,
    double width,
    double floorY,
  ) {
    final cab = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top + 28, width * 0.32, floorY - top - 34),
      const Radius.circular(4),
    );
    canvas.drawRRect(cab, IllustrationPaintHelpers.fill(AppColors.darkBlueLight));

    final trailer = RRect.fromRectAndRadius(
      Rect.fromLTWH(left + width * 0.3, top + 36, width * 0.68, floorY - top - 42),
      const Radius.circular(3),
    );
    canvas.drawRRect(trailer, IllustrationPaintHelpers.fill(const Color(0xFFD5DCE8)));
    canvas.drawRRect(trailer, IllustrationPaintHelpers.stroke(AppColors.darkBlueMuted, width: 1));

    canvas.drawCircle(
      Offset(left + width * 0.18, floorY - 6),
      7,
      IllustrationPaintHelpers.fill(AppColors.darkBlue),
    );
    canvas.drawCircle(
      Offset(left + width * 0.78, floorY - 6),
      7,
      IllustrationPaintHelpers.fill(AppColors.darkBlue),
    );
    canvas.drawCircle(
      Offset(left + width * 0.58, floorY - 6),
      7,
      IllustrationPaintHelpers.fill(AppColors.darkBlue),
    );

    final windshield = RRect.fromRectAndRadius(
      Rect.fromLTWH(left + 6, top + 34, width * 0.18, 16),
      const Radius.circular(2),
    );
    canvas.drawRRect(windshield, IllustrationPaintHelpers.fill(AppColors.infoBg));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
