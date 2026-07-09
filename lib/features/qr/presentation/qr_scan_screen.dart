import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/helpers/responsive_helper.dart';
import '../../../core/theme/app_icons.dart';
import '../../../providers/phase2_providers.dart';
import '../../../routing/route_paths.dart';
import '../../../widgets/widgets.dart';

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  final _manualController = TextEditingController();
  String? _scannedValue;
  bool _handled = false;

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _openOrder(String value) async {
    final order =
        await ref.read(searchServiceProvider).findByQrOrOrderNumber(value);
    if (!mounted) return;
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No matching production order found')),
      );
      return;
    }
    context.push(RoutePaths.orderDetailPath(order.id));
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    setState(() {
      _handled = true;
      _scannedValue = value;
    });
    _openOrder(value);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: ResponsiveHelper.pagePadding(context),
      child: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'QR Scanner',
              subtitle:
                  'Scan a QR code or enter an order number to open production details',
            ),
            const SizedBox(height: 16),
            AppCard(
              title: 'Camera Scanner',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 280,
                  child: MobileScanner(onDetect: _onDetect),
                ),
              ),
            ),
            if (_scannedValue != null) ...[
              const SizedBox(height: 12),
              Text('Scanned: $_scannedValue'),
            ],
            const SizedBox(height: 24),
            AppCard(
              title: 'Manual Entry',
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualController,
                      decoration: const InputDecoration(
                        labelText: 'Order Number or QR Value',
                        prefixIcon: Icon(AppIcons.qr),
                      ),
                      onSubmitted: _openOrder,
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => _openOrder(_manualController.text),
                    child: const Text('Open Order'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
