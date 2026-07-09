import 'package:flutter/material.dart';

import '../core/helpers/responsive_helper.dart';
import '../core/theme/app_colors.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final titleSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ],
    );

    if (actions == null || actions!.isEmpty) {
      return titleSection;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackActions = ResponsiveHelper.isMobile(context) ||
            constraints.maxWidth < 720;

        if (stackActions) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleSection,
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions!),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleSection),
            Flexible(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: actions!,
              ),
            ),
          ],
        );
      },
    );
  }
}
