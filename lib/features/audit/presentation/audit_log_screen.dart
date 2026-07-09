import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/date_helper.dart';
import '../../../core/helpers/responsive_helper.dart';
import '../../../providers/phase2_providers.dart';
import '../../../widgets/widgets.dart';

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditAsync = ref.watch(auditLogStreamProvider);

    return SingleChildScrollView(
      padding: ResponsiveHelper.pagePadding(context),
      child: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'System Audit Log',
              subtitle:
                  'Complete history of create, update, delete, transfer, approval, and login activity',
            ),
            const SizedBox(height: 24),
            auditAsync.when(
              loading: () => const AppLoadingIndicator(),
              error: (e, _) => AppErrorView(message: e.toString()),
              data: (entries) {
                if (entries.isEmpty) {
                  return const AppEmptyState(
                    title: 'No audit entries yet',
                    subtitle: 'System actions will be recorded here.',
                  );
                }
                return AppCard(
                  title: '${entries.length} entries',
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Action')),
                        DataColumn(label: Text('User')),
                        DataColumn(label: Text('Entity')),
                        DataColumn(label: Text('Notes')),
                        DataColumn(label: Text('Timestamp')),
                      ],
                      rows: entries.map((entry) {
                        return DataRow(
                          cells: [
                            DataCell(Text(entry.action.label)),
                            DataCell(Text(entry.performedByName)),
                            DataCell(
                              Text(
                                entry.entityType.isEmpty
                                    ? '—'
                                    : '${entry.entityType} ${entry.entityId}',
                              ),
                            ),
                            DataCell(Text(entry.notes)),
                            DataCell(
                              Text(
                                DateHelper.formatDateTime(entry.timestamp),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
