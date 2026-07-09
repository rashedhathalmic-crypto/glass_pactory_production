import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/helpers/responsive_helper.dart';
import '../../../core/helpers/order_status_tone_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../models/dashboard_stats_request.dart';
import '../../../models/department_order_summary.dart';
import '../../../models/production_order.dart';
import '../../../routing/route_paths.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/phase2_providers.dart';
import '../../../widgets/widgets.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late DashboardStatsRequest _statsRequest;

  @override
  void initState() {
    super.initState();
    _statsRequest = DashboardStatsRequest(DateTime.now());
  }

  void _refreshStats() {
    ref.invalidate(departmentOrderSummariesProvider);
    setState(() {
      _statsRequest = DashboardStatsRequest(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(extendedDashboardStatsProvider(_statsRequest));
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final padding = ResponsiveHelper.pagePadding(context);

    return SingleChildScrollView(
      padding: padding,
      child: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Production Dashboard',
              subtitle: 'Real-time overview of factory operations',
            ),
            const SizedBox(height: 24),
            statsAsync.when(
              skipLoadingOnReload: true,
              loading: () => const AppLoadingIndicator(),
              error: (e, _) => AppErrorView(
                message: e.toString(),
                onRetry: _refreshStats,
              ),
              data: (extended) {
                final stats = extended.phase1;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ResponsiveCardGrid(
                      itemCount: 6,
                      itemBuilder: (context, index) {
                        return switch (index) {
                          0 => StatCard(
                              label: 'Total Orders',
                              value: stats.totalOrders.toString(),
                              icon: AppIcons.orders,
                            ),
                          1 => StatCard(
                              label: 'In Progress',
                              value: stats.inProgressOrders.toString(),
                              icon: AppIcons.play,
                            ),
                          2 => StatCard(
                              label: 'Completed',
                              value: stats.completedOrders.toString(),
                              icon: AppIcons.complete,
                            ),
                          3 => StatCard(
                              label: 'On Hold',
                              value: stats.onHoldOrders.toString(),
                              icon: AppIcons.hold,
                            ),
                          4 => StatCard(
                              label: 'Overdue',
                              value: stats.overdueOrders.toString(),
                              icon: AppIcons.warning,
                            ),
                          _ => StatCard(
                              label: 'Active Users',
                              value: stats.activeUsers.toString(),
                              icon: AppIcons.users,
                            ),
                        };
                      },
                    ),
                    const SizedBox(height: 24),
                    ResponsiveCardGrid(
                      itemCount: 4,
                      itemBuilder: (context, index) => switch (index) {
                        0 => StatCard(
                            label: "Today's Orders",
                            value: extended.todaysOrders.toString(),
                            icon: AppIcons.calendar,
                          ),
                        1 => StatCard(
                            label: 'This Week',
                            value: extended.thisWeekOrders.toString(),
                            icon: AppIcons.reports,
                          ),
                        2 => StatCard(
                            label: 'Delayed Orders',
                            value: extended.delayedOrders.toString(),
                            icon: AppIcons.error,
                          ),
                        _ => StatCard(
                            label: 'Rework Orders',
                            value: extended.reworkOrders.toString(),
                            icon: AppIcons.hold,
                          ),
                      },
                    ),
                    const SizedBox(height: 24),
                    ResponsiveCardGrid(
                      itemCount: 2,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return AppCard(
                            title: 'Daily Production',
                            child: ProductionLineChart(
                              points: extended.dailyProduction,
                            ),
                          );
                        }
                        return AppCard(
                          title: 'Department Production',
                          child: DepartmentBarChart(
                            points: extended.departmentProduction,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    ResponsiveCardGrid(
                      itemCount: 2,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return AppCard(
                            title: 'Monthly Production',
                            child: ProductionLineChart(
                              points: extended.monthlyProduction,
                            ),
                          );
                        }
                        return AppCard(
                          title: 'Rework Trend',
                          child: ProductionLineChart(
                            points: extended.reworkTrend,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    ResponsiveCardGrid(
                      itemCount: 2,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return AppCard(
                            title: 'Department Workload',
                            child: Column(
                              children: [
                                for (final summary in stats.recentOrders)
                                  _DepartmentRow(summary: summary),
                              ],
                            ),
                          );
                        }
                        return AppCard(
                          title: 'Delivery Status Summary',
                          child: DeliverySummaryCard(
                            summary: extended.deliverySummary,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    ResponsiveCardGrid(
                      itemCount: 2,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return AppCard(
                            title: 'Recent Activities',
                            child: ActivityTimeline(
                              entries: extended.recentActivities,
                            ),
                          );
                        }
                        return AppCard(
                          title: 'Notification Panel',
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  context.go(RoutePaths.notifications),
                              child: const Text('Open Center'),
                            ),
                          ],
                          child: notificationsAsync.when(
                            loading: () => const AppLoadingIndicator(),
                            error: (e, _) => Text(e.toString()),
                            data: (messages) {
                              final unread =
                                  messages.where((m) => !m.isRead).length;
                              if (messages.isEmpty) {
                                return const Text(
                                  'No notifications',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$unread unread',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  for (final message in messages.take(4))
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(message.title),
                                      subtitle: Text(message.message),
                                    ),
                                ],
                              );
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    AppCard(
                      title: 'Recent Production Orders',
                      actions: [
                        TextButton(
                          onPressed: () => context.go(RoutePaths.orders),
                          child: const Text('View All'),
                        ),
                      ],
                      child: extended.recentOrders.isEmpty
                          ? const AppEmptyState(
                              title: 'No production orders yet',
                              subtitle:
                                  'Create your first order to begin tracking production.',
                            )
                          : _OrdersTable(orders: extended.recentOrders),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentRow extends StatelessWidget {
  const _DepartmentRow({required this.summary});

  final DepartmentOrderSummary summary;

  @override
  Widget build(BuildContext context) {
    final isCompact = ResponsiveHelper.isMobile(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.department.label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Text(
                  '${summary.activeCount} active · ${summary.pendingCount} hold · ${summary.completedCount} done',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    summary.department.label,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${summary.activeCount} active',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${summary.pendingCount} hold',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${summary.completedCount} done',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _OrdersTable extends StatelessWidget {
  const _OrdersTable({required this.orders});

  final List<ProductionOrder> orders;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    if (isMobile) {
      return Column(
        children: [for (final order in orders) _OrderListTile(order: order)],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Order #')),
          DataColumn(label: Text('Customer')),
          DataColumn(label: Text('Department')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Priority')),
        ],
        rows: orders.map((order) {
          return DataRow(
            onSelectChanged: (_) =>
                context.push(RoutePaths.orderDetailPath(order.id)),
            cells: [
              DataCell(Text(order.orderNumber)),
              DataCell(Text(order.customerName)),
              DataCell(Text(order.currentDepartment.shortLabel)),
              DataCell(
                StatusChip(
                  label: order.status.label,
                  tone: OrderStatusToneHelper.toneFor(order.status),
                ),
              ),
              DataCell(Text(order.priority.label)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _OrderListTile extends StatelessWidget {
  const _OrderListTile({required this.order});

  final ProductionOrder order;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(order.orderNumber),
      subtitle: Text(
        '${order.customerName} · ${order.currentDepartment.label}',
      ),
      trailing: StatusChip(
        label: order.status.label,
        tone: OrderStatusToneHelper.toneFor(order.status),
      ),
      onTap: () => context.push(RoutePaths.orderDetailPath(order.id)),
    );
  }
}
