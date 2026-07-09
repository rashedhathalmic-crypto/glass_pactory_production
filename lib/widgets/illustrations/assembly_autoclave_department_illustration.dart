import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'illustration_paint_helpers.dart';

class AssemblyAutoclaveDepartmentIllustration extends StatelessWidget {
  const AssemblyAutoclaveDepartmentIllustration({super.key});

  static const double preferredHeight = 180;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _AssemblyAutoclavePainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _AssemblyAutoclavePainter extends CustomPainter {
  const _AssemblyAutoclavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final floorY = h * 0.82;

    IllustrationPaintHelpers.paintBackground(canvas, size);
    IllustrationPaintHelpers.paintFloor(canvas, w, floorY);

    _paintLaminatedGlass(canvas, w * 0.1, h * 0.55, w * 0.28);
    _paintPolycarbonate(canvas, w * 0.12, h * 0.48, w * 0.24);
    _paintAutoclave(canvas, w * 0.48, h * 0.22, w * 0.42, floorY);
  }

  void _paintLaminatedGlass(Canvas canvas, double left, double top, double width) {
    for (var i = 0; i < 3; i++) {
      IllustrationPaintHelpers.paintGlassSheet(
        canvas,
        Rect.fromLTWH(left + i * 4, top + i * 5, width, 16),
        strokeAlpha: 0.25,
      );
    }
    canvas.drawLine(
      Offset(left + 8, top + 24),
      Offset(left + width - 8, top + 24),
      IllustrationPaintHelpers.stroke(AppColors.darkBlue.withValues(alpha: 0.15), width: 1),
    );
  }

  void _paintPolycarbonate(Canvas canvas, double left, double top, double width) {
    final panel = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, 20),
      const Radius.circular(2),
    );
    canvas.drawRRect(
      panel,
      IllustrationPaintHelpers.fill(const Color(0xFFE8EDF5).withValues(alpha: 0.9)),
    );
    canvas.drawRRect(panel, IllustrationPaintHelpers.stroke(AppColors.darkBlueMuted.withValues(alpha: 0.25)));
    for (var i = 1; i < 5; i++) {
      canvas.drawLine(
        Offset(left + i * (width / 5), top),
        Offset(left + i * (width / 5), top + 20),
        IllustrationPaintHelpers.stroke(AppColors.border, width: 0.8),
      );
    }
  }

  void _paintAutoclave(
    Canvas canvas,
    double left,
    double top,
    double width,
    double floorY,
  ) {
    final vessel = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top + 24, width, floorY - top - 30),
      Radius.circular(width * 0.22),
    );
    canvas.drawRRect(vessel, IllustrationPaintHelpers.fill(const Color(0xFFB8C4D4)));
    canvas.drawRRect(vessel, IllustrationPaintHelpers.stroke(AppColors.darkBlueMuted, width: 1.5));

    final door = RRect.fromRectAndRadius(
      Rect.fromLTWH(left + width * 0.18, top + 48, width * 0.64, floorY - top - 58),
      const Radius.circular(12),
    );
    canvas.drawRRect(door, IllustrationPaintHelpers.fill(AppColors.darkBlueLight));
    canvas.drawRRect(door, IllustrationPaintHelpers.stroke(AppColors.darkBlue, width: 1.2));

    final gauge = Offset(left + width * 0.82, top + 44);
    canvas.drawCircle(gauge, 10, IllustrationPaintHelpers.fill(AppColors.white));
    canvas.drawCircle(gauge, 10, IllustrationPaintHelpers.stroke(AppColors.darkBlue, width: 1));
    canvas.drawLine(
      gauge,
      Offset(gauge.dx + 5, gauge.dy - 3),
      IllustrationPaintHelpers.stroke(AppColors.error, width: 1.5),
    );

    final stack = RRect.fromRectAndRadius(
      Rect.fromLTWH(left + width * 0.35, top, width * 0.3, 28),
      const Radius.circular(4),
    );
    canvas.drawRRect(stack, IllustrationPaintHelpers.fill(AppColors.darkBlue));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
