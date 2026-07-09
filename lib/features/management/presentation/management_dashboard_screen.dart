import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/helpers/responsive_helper.dart';
import '../../../core/theme/app_icons.dart';
import '../../../models/dashboard_stats_request.dart';
import '../../../models/enums/department.dart';
import '../../../models/enums/message_priority.dart';
import '../../../models/enums/message_type.dart';
import '../../../models/enums/recipient_scope.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../core/permissions/app_permission.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/phase2_providers.dart';
import '../../../routing/route_paths.dart';
import '../../../utils/extensions/extensions.dart';
import '../../../widgets/widgets.dart';

class ManagementDashboardScreen extends ConsumerStatefulWidget {
  const ManagementDashboardScreen({super.key});

  @override
  ConsumerState<ManagementDashboardScreen> createState() =>
      _ManagementDashboardScreenState();
}

class _ManagementDashboardScreenState
    extends ConsumerState<ManagementDashboardScreen> {
  late DashboardStatsRequest _request;

  @override
  void initState() {
    super.initState();
    _request = DashboardStatsRequest(DateTime.now());
  }

  void _refresh() {
    ref.invalidate(departmentOrderSummariesProvider);
    setState(() => _request = DashboardStatsRequest(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    final statsAsync = ref.watch(extendedDashboardStatsProvider(_request));
    final alertsAsync = ref.watch(alertsStreamProvider);

    return SingleChildScrollView(
      padding: ResponsiveHelper.pagePadding(context),
      child: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Management Dashboard',
              subtitle: 'Live factory status and production monitoring',
              actions: [
                if (user?.hasPermission(AppPermission.sendNotifications) ?? false)
                  OutlinedButton.icon(
                    onPressed: () => _showAlertDialog(user!),
                    icon: const Icon(AppIcons.warning, size: 18),
                    label: const Text('Send Alert'),
                  ),
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(AppIcons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 24),
            statsAsync.when(
              loading: () => const AppLoadingIndicator(),
              error: (e, _) =>
                  AppErrorView(message: e.toString(), onRetry: _refresh),
              data: (stats) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ResponsiveCardGrid(
                    itemCount: 8,
                    itemBuilder: (context, index) => switch (index) {
                      0 => StatCard(
                          label: 'Today',
                          value: stats.todaysOrders.toString(),
                          icon: AppIcons.calendar,
                        ),
                      1 => StatCard(
                          label: 'This Week',
                          value: stats.thisWeekOrders.toString(),
                          icon: AppIcons.reports,
                        ),
                      2 => StatCard(
                          label: 'This Month',
                          value: stats.thisMonthOrders.toString(),
                          icon: AppIcons.reports,
                        ),
                      3 => StatCard(
                          label: 'Delayed',
                          value: stats.delayedOrders.toString(),
                          icon: AppIcons.warning,
                        ),
                      4 => StatCard(
                          label: 'Rework',
                          value: stats.reworkOrders.toString(),
                          icon: AppIcons.hold,
                        ),
                      5 => StatCard(
                          label: 'In Progress',
                          value: stats.phase1.inProgressOrders.toString(),
                          icon: AppIcons.play,
                        ),
                      6 => StatCard(
                          label: 'Completed',
                          value: stats.phase1.completedOrders.toString(),
                          icon: AppIcons.complete,
                        ),
                      _ => StatCard(
                          label: 'Overdue',
                          value: stats.phase1.overdueOrders.toString(),
                          icon: AppIcons.error,
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
                            points: stats.dailyProduction,
                          ),
                        );
                      }
                      return AppCard(
                        title: 'Monthly Production',
                        child: ProductionLineChart(
                          points: stats.monthlyProduction,
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
                          title: 'Department Status',
                          child: DepartmentBarChart(
                            points: stats.departmentProduction,
                          ),
                        );
                      }
                      return AppCard(
                        title: 'Delivery Summary',
                        child: DeliverySummaryCard(
                          summary: stats.deliverySummary,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    title: 'Department Workload',
                    child: Column(
                      children: [
                        for (final summary in stats.phase1.recentOrders)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(summary.department.label),
                            subtitle: Text(
                              '${summary.activeCount} active · '
                              '${summary.pendingCount} hold · '
                              '${summary.completedCount} done',
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    title: 'Recent Activity',
                    child: ActivityTimeline(entries: stats.recentActivities),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            alertsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (alerts) {
                if (alerts.isEmpty) return const SizedBox.shrink();
                return AppCard(
                  title: 'Internal Alerts',
                  child: Column(
                    children: [
                      for (final alert in alerts.take(5))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(alert.title),
                          subtitle: Text(alert.message),
                          trailing: alert.isRead
                              ? null
                              : const Icon(AppIcons.warning, size: 18),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => context.go(RoutePaths.productionManagement),
                child: const Text('Open Production Management'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAlertDialog(dynamic user) async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    var type = MessageType.general;
    var priority = MessagePriority.high;
    var scope = RecipientScope.everyone;
    Department? department;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Send Alert'),
          content: SizedBox(
            width: 420,
            child: MessageComposeFields(
              titleController: titleController,
              messageController: messageController,
              type: type,
              priority: priority,
              scope: scope,
              department: department,
              includeMaintenanceType: true,
              onTypeChanged: (value) => setLocalState(() => type = value),
              onPriorityChanged: (value) =>
                  setLocalState(() => priority = value),
              onScopeChanged: (value) => setLocalState(() => scope = value),
              onDepartmentChanged: (value) =>
                  setLocalState(() => department = value),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await ref.read(alertServiceProvider).sendMessage(
                      sender: user,
                      title: titleController.text,
                      message: messageController.text,
                      type: type,
                      priority: priority,
                      scope: scope,
                      department: department,
                    );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Send Alert'),
            ),
          ],
        ),
      ),
    );
  }
}
