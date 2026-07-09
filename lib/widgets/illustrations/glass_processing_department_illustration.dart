import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Flat industrial illustration for the Glass Processing department.
class GlassProcessingDepartmentIllustration extends StatelessWidget {
  const GlassProcessingDepartmentIllustration({super.key});

  static const double preferredHeight = 180;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _GlassProcessingIllustrationPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _GlassProcessingIllustrationPainter extends CustomPainter {
  const _GlassProcessingIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _paintBackground(canvas, size);

    final floorY = h * 0.82;
    final tableTop = h * 0.62;
    final tableLeft = w * 0.12;
    final tableRight = w * 0.88;
    final tableWidth = tableRight - tableLeft;

    _paintFloor(canvas, w, floorY);
    _paintMachineBase(canvas, tableLeft, tableTop, tableWidth, floorY);
    _paintGlassSheet(canvas, tableLeft, tableTop, tableWidth);
    _paintGantry(canvas, tableLeft, tableTop, tableWidth, h);
    _paintProcessingHead(canvas, w * 0.58, tableTop, h);
    _paintControlPanel(canvas, w * 0.14, tableTop, h);
    _paintAccentDetails(canvas, tableLeft, tableTop, tableWidth, floorY);
  }

  void _paintBackground(Canvas canvas, Size size) {
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

  void _paintFloor(Canvas canvas, double width, double floorY) {
    canvas.drawLine(
      Offset(0, floorY),
      Offset(width, floorY),
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 1.2,
    );
    final shadow = Paint()..color = AppColors.darkBlue.withValues(alpha: 0.04);
    canvas.drawRect(Rect.fromLTWH(0, floorY, width, 6), shadow);
  }

  void _paintMachineBase(
    Canvas canvas,
    double left,
    double tableTop,
    double width,
    double floorY,
  ) {
    final baseRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, tableTop + 18, width, floorY - tableTop - 14),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      baseRect,
      Paint()..color = const Color(0xFFD5DCE8),
    );
    canvas.drawRRect(
      baseRect,
      Paint()
        ..color = AppColors.darkBlueMuted.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final railPaint = Paint()
      ..color = AppColors.mediumGray.withValues(alpha: 0.35)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(left + 12, tableTop + 30),
      Offset(left + width - 12, tableTop + 30),
      railPaint,
    );
  }

  void _paintGlassSheet(
    Canvas canvas,
    double left,
    double tableTop,
    double width,
  ) {
    final glassRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left + 28, tableTop - 8, width - 56, 22),
      const Radius.circular(2),
    );

    canvas.drawRRect(
      glassRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppColors.infoBg.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.75),
            AppColors.infoBg.withValues(alpha: 0.55),
          ],
        ).createShader(glassRect.outerRect),
    );
    canvas.drawRRect(
      glassRect,
      Paint()
        ..color = AppColors.info.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final highlight = Paint()..color = Colors.white.withValues(alpha: 0.65);
    canvas.drawLine(
      Offset(left + 40, tableTop - 2),
      Offset(left + width * 0.55, tableTop - 2),
      highlight..strokeWidth = 1.5,
    );

    final cutLine = Paint()
      ..color = AppColors.darkBlue
      ..strokeWidth = 1.4;
    final cutX = left + width * 0.52;
    canvas.drawLine(
      Offset(cutX, tableTop - 8),
      Offset(cutX, tableTop + 14),
      cutLine,
    );
  }

  void _paintGantry(
    Canvas canvas,
    double left,
    double tableTop,
    double width,
    double height,
  ) {
    final pillarPaint = Paint()..color = AppColors.darkBlueMuted;
    final leftPillar = Rect.fromLTWH(left + width * 0.18, tableTop - 46, 10, 58);
    final rightPillar = Rect.fromLTWH(left + width * 0.72, tableTop - 46, 10, 58);
    canvas.drawRRect(
      RRect.fromRectAndRadius(leftPillar, const Radius.circular(2)),
      pillarPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rightPillar, const Radius.circular(2)),
      pillarPaint,
    );

    final beamRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left + width * 0.16, tableTop - 52, width * 0.68, 10),
      const Radius.circular(3),
    );
    canvas.drawRRect(beamRect, Paint()..color = AppColors.darkBlue);
    canvas.drawRRect(
      beamRect,
      Paint()
        ..color = AppColors.darkBlueLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final motor = Rect.fromLTWH(left + width * 0.54, tableTop - 66, 22, 14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(motor, const Radius.circular(2)),
      Paint()..color = AppColors.darkBlueLight,
    );
  }

  void _paintProcessingHead(Canvas canvas, double x, double tableTop, double height) {
    final headBody = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, tableTop - 18), width: 18, height: 28),
      const Radius.circular(3),
    );
    canvas.drawRRect(headBody, Paint()..color = AppColors.darkBlueLight);

    final nozzle = Path()
      ..moveTo(x - 4, tableTop - 4)
      ..lineTo(x + 4, tableTop - 4)
      ..lineTo(x, tableTop + 8)
      ..close();
    canvas.drawPath(nozzle, Paint()..color = AppColors.darkBlue);

    final sparkPaint = Paint()..color = AppColors.info.withValues(alpha: 0.55);
    canvas.drawCircle(Offset(x, tableTop + 10), 2.2, sparkPaint);
    canvas.drawCircle(Offset(x - 3, tableTop + 12), 1.4, sparkPaint);
    canvas.drawCircle(Offset(x + 2.5, tableTop + 13), 1.2, sparkPaint);
  }

  void _paintControlPanel(
    Canvas canvas,
    double left,
    double tableTop,
    double height,
  ) {
    final panel = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, tableTop + 34, 42, 34),
      const Radius.circular(4),
    );
    canvas.drawRRect(panel, Paint()..color = AppColors.darkBlue);
    canvas.drawRRect(
      panel,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final screen = RRect.fromRectAndRadius(
      Rect.fromLTWH(left + 8, tableTop + 42, 26, 12),
      const Radius.circular(2),
    );
    canvas.drawRRect(screen, Paint()..color = AppColors.infoBg);

    final buttonPaint = Paint()..color = AppColors.successBg;
    canvas.drawCircle(Offset(left + 14, tableTop + 60), 2.5, buttonPaint);
    canvas.drawCircle(Offset(left + 22, tableTop + 60), 2.5, buttonPaint);
    canvas.drawCircle(Offset(left + 30, tableTop + 60), 2.5, buttonPaint);
  }

  void _paintAccentDetails(
    Canvas canvas,
    double left,
    double tableTop,
    double width,
    double floorY,
  ) {
    final detailPaint = Paint()
      ..color = AppColors.darkBlue.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 0; i < 4; i++) {
      final x = left + 24 + (i * (width - 48) / 3);
      canvas.drawLine(Offset(x, floorY + 8), Offset(x, floorY + 18), detailPaint);
    }

    final labelBg = RRect.fromRectAndRadius(
      Rect.fromLTWH(left + width - 96, tableTop - 38, 82, 20),
      const Radius.circular(10),
    );
    canvas.drawRRect(labelBg, Paint()..color = Colors.white.withValues(alpha: 0.82));
    canvas.drawRRect(
      labelBg,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
