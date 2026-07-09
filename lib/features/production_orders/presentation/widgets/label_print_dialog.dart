import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/production_order.dart';

class LabelPrintDialog extends StatelessWidget {
  const LabelPrintDialog({
    super.key,
    required this.order,
    this.showQr = false,
  });

  final ProductionOrder order;
  final bool showQr;

  String get _qrUrl {
    final data = Uri.encodeComponent(order.orderNumber);
    return 'https://quickchart.io/qr?text=$data&size=200';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(showQr ? 'Order QR Code' : 'Shipping Label'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!showQr) ...[
              Text(
                order.orderNumber,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(order.customerName),
              Text(order.glassType),
              Text(order.drawingNumber),
              Text(order.dimensionsLabel),
              Text('Qty: ${order.quantity}'),
              const Divider(height: 24),
            ],
            Center(
              child: Image.network(
                _qrUrl,
                width: 200,
                height: 200,
                errorBuilder: (_, _, _) => Container(
                  width: 200,
                  height: 200,
                  color: AppColors.lightGray,
                  alignment: Alignment.center,
                  child: Text(order.orderNumber),
                ),
              ),
            ),
            if (showQr) ...[
              const SizedBox(height: 8),
              Text(
                order.orderNumber,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
