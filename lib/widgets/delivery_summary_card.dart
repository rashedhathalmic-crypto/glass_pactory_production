import 'package:flutter/material.dart';

import '../models/enums/delivery_status.dart';

class DeliverySummaryCard extends StatelessWidget {
  const DeliverySummaryCard({super.key, required this.summary});

  final Map<DeliveryStatus, int> summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final status in DeliveryStatus.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: Text(status.label)),
                Text(
                  '${summary[status] ?? 0}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
