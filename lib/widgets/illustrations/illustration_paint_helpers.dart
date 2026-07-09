import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Shared painting utilities for industrial department illustrations.
abstract final class IllustrationPaintHelpers {
  static void paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.offWhite,
        const Color(0xFFEEF2F8),
        AppColors.lightGray.withValues(alpha: 0.45),
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  static void paintFloor(Canvas canvas, double width, double floorY) {
    canvas.drawLine(
      Offset(0, floorY),
      Offset(width, floorY),
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 1.2,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, floorY, width, 6),
      Paint()..color = AppColors.darkBlue.withValues(alpha: 0.04),
    );
  }

  static void paintGlassSheet(
    Canvas canvas,
    Rect rect, {
    double strokeAlpha = 0.35,
  }) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppColors.infoBg.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.75),
            AppColors.infoBg.withValues(alpha: 0.55),
          ],
        ).createShader(rrect.outerRect),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = AppColors.info.withValues(alpha: strokeAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  static Paint fill(Color color) => Paint()..color = color;

  static Paint stroke(Color color, {double width = 1}) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width;
}
