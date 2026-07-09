import 'package:flutter/material.dart';

import '../core/helpers/date_helper.dart';
import '../core/theme/app_colors.dart';
import '../models/order_history_entry.dart';

class ActivityTimeline extends StatelessWidget {
  const ActivityTimeline({super.key, required this.entries});

  final List<OrderHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Text(
        'No recent activity',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }

    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: const BoxDecoration(
                    color: AppColors.info,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.action.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entry.performedByName} · Order ${entry.orderId}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      if (entry.notes.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          entry.notes,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                      if (entry.timestamp != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          DateHelper.formatDateTime(entry.timestamp!),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
