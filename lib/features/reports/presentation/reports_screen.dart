import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/responsive_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/enums/department.dart';
import '../../../models/enums/order_status.dart';
import '../../../models/enums/report_type.dart';
import '../../../models/order_filters.dart';
import '../../../models/report_period.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/phase2_providers.dart';
import '../../../core/theme/app_icons.dart';
import '../../../widgets/widgets.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  ReportType _reportType = ReportType.dailyProduction;
  OrderFilters _filters = const OrderFilters();

  ReportPeriod get _period =>
      ReportPeriod(startDate: _startDate, endDate: _endDate);

  ProductionReportRequest get _request => ProductionReportRequest(
        type: _reportType,
        period: _period,
        filters: _filters,
      );

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(productionReportProvider(_request));
    final summaryAsync = ref.watch(reportSummaryProvider(_period));

    return SingleChildScrollView(
      padding: ResponsiveHelper.pagePadding(context),
      child: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Production Reports',
              subtitle:
                  'Daily, weekly, monthly, department, delayed, rework, and delivery reports',
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final fieldWidth = constraints.maxWidth >= 640
                    ? 240.0
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: fieldWidth,
                      child: DropdownButtonFormField<ReportType>(
                        key: ValueKey(_reportType),
                        isExpanded: true,
                        initialValue: _reportType,
                        decoration:
                            const InputDecoration(labelText: 'Report Type'),
                        items: [
                          for (final type in ReportType.values)
                            DropdownMenuItem(
                              value: type,
                              child: Text(
                                type.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _reportType = value);
                        },
                      ),
                    ),
                OutlinedButton.icon(
                  onPressed: () => _pickDate(isStart: true),
                  icon: const Icon(AppIcons.calendar, size: 18),
                  label: Text(
                    _startDate == null
                        ? 'Start Date'
                        : _startDate!.toLocal().toString().split(' ').first,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickDate(isStart: false),
                  icon: const Icon(AppIcons.calendar, size: 18),
                  label: Text(
                    _endDate == null
                        ? 'End Date'
                        : _endDate!.toLocal().toString().split(' ').first,
                  ),
                ),
                if (_startDate != null || _endDate != null)
                  TextButton(
                    onPressed: () => setState(() {
                      _startDate = null;
                      _endDate = null;
                    }),
                    child: const Text('Clear Dates'),
                  ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            OrderFiltersPanel(
              filters: _filters,
              onChanged: (value) => setState(() => _filters = value),
              onClear: () => setState(() => _filters = const OrderFilters()),
            ),
            const SizedBox(height: 24),
            reportAsync.when(
              skipLoadingOnReload: true,
              loading: () => const AppLoadingIndicator(),
              error: (e, _) => AppErrorView(
                message: e.toString(),
                onRetry: () =>
                    ref.invalidate(productionReportProvider(_request)),
              ),
              data: (report) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          '${report.title} · ${report.periodLabel}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            ref.read(exportServiceProvider).exportPdf(report),
                        icon: const Icon(AppIcons.download, size: 18),
                        label: const Text('PDF'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            ref.read(exportServiceProvider).exportExcel(report),
                        icon: const Icon(AppIcons.download, size: 18),
                        label: const Text('Excel'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (report.summaryRows.isNotEmpty)
                    ResponsiveCardGrid(
                      itemCount: report.summaryRows.length.clamp(1, 4),
                      itemBuilder: (context, index) => StatCard(
                        label: report.summaryRows[index].label,
                        value: report.summaryRows[index].value,
                        icon: AppIcons.reports,
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (report.departmentRows.isNotEmpty)
                    AppCard(
                      title: 'Department Breakdown',
                      child: Column(
                        children: [
                          for (final dept in Department.values)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(child: Text(dept.label)),
                                  Text(
                                    '${report.departmentRows[dept] ?? 0}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (report.productionTimeRows.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    AppCard(
                      title: 'Production Time by Department',
                      child: Column(
                        children: [
                          for (final row in report.productionTimeRows.take(50))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(row.orderNumber),
                              subtitle: Text(row.department.label),
                              trailing: Text(
                                '${row.hours.toStringAsFixed(1)} h',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (report.orders.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    AppCard(
                      title: 'Orders (${report.orders.length})',
                      child: Column(
                        children: [
                          for (final order in report.orders.take(50))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(order.orderNumber),
                              subtitle: Text(
                                '${order.customerName} · ${order.currentDepartment.label}',
                              ),
                              trailing: Text(order.status.label),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            summaryAsync.when(
              skipLoadingOnReload: true,
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (summary) => AppCard(
                title: 'Summary Metrics',
                actions: [
                  OutlinedButton(
                    onPressed: () => ref
                        .read(exportServiceProvider)
                        .exportSummaryPdf(summary),
                    child: const Text('Export Summary PDF'),
                  ),
                ],
                child: Column(
                  children: [
                    for (final status in OrderStatus.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(status.label)),
                            Text(
                              '${summary.statusBreakdown[status] ?? 0}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
