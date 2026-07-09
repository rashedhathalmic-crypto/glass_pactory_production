import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/open_url_helper.dart';
import '../../../core/helpers/responsive_helper.dart';
import '../../../core/theme/app_icons.dart';
import '../../../models/drawing_archive_item.dart';
import '../../../providers/phase2_providers.dart';
import '../../../widgets/widgets.dart';

class DrawingArchiveScreen extends ConsumerStatefulWidget {
  const DrawingArchiveScreen({super.key});

  @override
  ConsumerState<DrawingArchiveScreen> createState() =>
      _DrawingArchiveScreenState();
}

class _DrawingArchiveScreenState extends ConsumerState<DrawingArchiveScreen> {
  String _search = '';
  String _customer = '';
  String _project = '';

  DrawingArchiveQuery get _query => DrawingArchiveQuery(
        search: _search,
        customer: _customer,
        project: _project,
      );

  @override
  Widget build(BuildContext context) {
    final archiveAsync = ref.watch(drawingArchiveProvider(_query));

    return SingleChildScrollView(
      padding: ResponsiveHelper.pagePadding(context),
      child: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Drawing Archive',
              subtitle: 'View and download PDF and DXF files for all orders',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 200,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search Drawings',
                      prefixIcon: Icon(AppIcons.search),
                    ),
                    onChanged: (value) => setState(() => _search = value),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Customer'),
                    onChanged: (value) => setState(() => _customer = value),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Project'),
                    onChanged: (value) => setState(() => _project = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            archiveAsync.when(
              loading: () => const AppLoadingIndicator(),
              error: (e, _) => AppErrorView(message: e.toString()),
              data: (items) {
                if (items.isEmpty) {
                  return const AppEmptyState(
                    title: 'No drawings found',
                    subtitle: 'Upload PDF or DXF files on production orders.',
                  );
                }
                return AppCard(
                  title: '${items.length} drawing(s)',
                  child: Column(
                    children: [
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.orderNumber} · ${item.drawingNumber}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${item.customerName} · ${item.projectName}',
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (item.pdfUrl.isNotEmpty) ...[
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          openExternalUrl(item.pdfUrl),
                                      icon: const Icon(AppIcons.visibility,
                                          size: 18),
                                      label: const Text('View PDF'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          openExternalUrl(item.pdfUrl),
                                      icon: const Icon(AppIcons.download,
                                          size: 18),
                                      label: const Text('Download PDF'),
                                    ),
                                  ],
                                  if (item.dxfUrl.isNotEmpty) ...[
                                    OutlinedButton.icon(
                                      onPressed: () => _showDxfInfo(item),
                                      icon: const Icon(AppIcons.visibility,
                                          size: 18),
                                      label: const Text('View DXF Info'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          openExternalUrl(item.dxfUrl),
                                      icon: const Icon(AppIcons.download,
                                          size: 18),
                                      label: const Text('Download DXF'),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDxfInfo(DrawingArchiveItem item) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DXF Information'),
        content: Text(
          'Order: ${item.orderNumber}\n'
          'Drawing: ${item.drawingNumber}\n'
          'Glass Type: ${item.glassType}\n'
          'File: ${item.dxfUrl}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
