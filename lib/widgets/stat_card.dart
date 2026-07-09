import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.trend,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? trend;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = constraints.maxHeight;
          final maxWidth = constraints.maxWidth;
          final hasBoundedHeight = maxHeight.isFinite;

          final horizontalPadding = maxWidth < 200 ? 10.0 : 16.0;
          final verticalPadding = hasBoundedHeight && maxHeight < 80 ? 6.0 : 14.0;
          final compact = hasBoundedHeight && maxHeight < 100;

          final content = _StatCardBody(
            label: label,
            value: value,
            icon: icon,
            trend: trend,
            compact: compact,
            contentWidth: maxWidth.isFinite
                ? maxWidth - (horizontalPadding * 2)
                : null,
          );

          final padded = Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: hasBoundedHeight
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: content,
                  )
                : content,
          );

          if (!hasBoundedHeight) return padded;

          return Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: maxWidth.isFinite ? maxWidth : null,
              height: maxHeight,
              child: padded,
            ),
          );
        },
      ),
    );
  }
}

class _StatCardBody extends StatelessWidget {
  const _StatCardBody({
    required this.label,
    required this.value,
    required this.icon,
    required this.trend,
    required this.compact,
    required this.contentWidth,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? trend;
  final bool compact;
  final double? contentWidth;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      color: AppColors.textSecondary,
      fontSize: compact ? 11 : 13,
      fontWeight: FontWeight.w500,
      height: 1.1,
    );
    final valueStyle = TextStyle(
      fontSize: compact ? 20 : 26,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      letterSpacing: -0.5,
      height: 1.0,
    );
    final trendStyle = TextStyle(
      fontSize: compact ? 10 : 12,
      color: AppColors.textSecondary,
      height: 1.0,
    );

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: compact ? 14 : 18,
                color: AppColors.darkBlueMuted,
              ),
              SizedBox(width: compact ? 6 : 8),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 4 : 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: valueStyle,
        ),
        if (trend != null) ...[
          SizedBox(height: compact ? 2 : 4),
          Text(
            trend!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: trendStyle,
          ),
        ],
      ],
    );

    if (contentWidth == null) return body;

    return SizedBox(
      width: contentWidth,
      child: body,
    );
  }
}
