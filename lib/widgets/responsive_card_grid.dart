import 'package:flutter/material.dart';

import '../core/helpers/responsive_helper.dart';

/// Lays out equal-width cards in a responsive grid without fixed tile heights.
class ResponsiveCardGrid extends StatelessWidget {
  const ResponsiveCardGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.columns,
    this.spacing = 16,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final int? columns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final columnCount = columns ?? ResponsiveHelper.gridColumns(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSpacing = spacing * (columnCount - 1);
        final itemWidth = columnCount <= 1
            ? constraints.maxWidth
            : ((constraints.maxWidth - totalSpacing) / columnCount)
                .floorToDouble();

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(
            itemCount,
            (index) => SizedBox(
              width: itemWidth,
              child: itemBuilder(context, index),
            ),
          ),
        );
      },
    );
  }
}
