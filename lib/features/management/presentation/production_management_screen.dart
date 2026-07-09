import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/helpers/responsive_helper.dart';
import '../../../core/theme/app_icons.dart';
import '../../../models/enums/department.dart';
import '../../../models/enums/order_priority.dart';
import '../../../models/enums/order_status.dart';
import '../../../models/production_order.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/phase2_providers.dart';
import '../../../routing/route_paths.dart';
import '../../../utils/extensions/extensions.dart';
import '../../../widgets/widgets.dart';

class ProductionManagementScreen extends ConsumerStatefulWidget {
  const ProductionManagementScreen({super.key});

  @override
  ConsumerState<ProductionManagementScreen> createState() =>
      _ProductionManagementScreenState();
}

class _ProductionManagementScreenState
    extends ConsumerState<ProductionManagementScreen> {
  List<ProductionOrder> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = ref.read(currentAppUserProvider).asData?.value;
      if (user == null) return;
      final orders = await ref
          .read(productionManagementServiceProvider)
          .fetchAllOrders(performer: user);
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    final canManage = user?.role.canManageProduction() ?? false;

    return SingleChildScrollView(
      padding: ResponsiveHelper.pagePadding(context),
      child: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Production Management',
              subtitle:
                  'Monitor orders, reassign departments, and manage priorities',
              actions: [
                IconButton(
                  onPressed: _load,
                  icon: const Icon(AppIcons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_loading)
              const AppLoadingIndicator()
            else if (_error != null)
              AppErrorView(message: _error!, onRetry: _load)
            else if (_orders.isEmpty)
              const AppEmptyState(title: 'No production orders found')
            else
              AppCard(
                title: '${_orders.length} orders',
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Order #')),
                      DataColumn(label: Text('Customer')),
                      DataColumn(label: Text('Department')),
                      DataColumn(label: Text('Priority')),
                      DataColumn(label: Text('Stopped')),
                      DataColumn(label: Text('Stop Reason')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _orders.map((order) {
                      return DataRow(
                        cells: [
                          DataCell(
                            TextButton(
                              onPressed: () => context.push(
                                RoutePaths.orderDetailPath(order.id),
                              ),
                              child: Text(order.orderNumber),
                            ),
                          ),
                          DataCell(Text(order.customerName)),
                          DataCell(Text(order.currentDepartment.label)),
                          DataCell(Text(order.priority.label)),
                          DataCell(Text(order.isStopped ? 'Yes' : 'No')),
                          DataCell(Text(order.stopReason)),
                          DataCell(
                            canManage
                                ? _ActionsMenu(
                                    order: order,
                                    onChanged: _load,
                                  )
                                : const Text('—'),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionsMenu extends ConsumerWidget {
  const _ActionsMenu({required this.order, required this.onChanged});

  final ProductionOrder order;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    if (user == null) return const SizedBox.shrink();
    final service = ref.read(productionManagementServiceProvider);

    return PopupMenuButton<String>(
      onSelected: (value) async {
        switch (value) {
          case 'stop':
            final reason = await _promptText(
              context,
              title: 'Stop Order',
              label: 'Stop Reason',
            );
            if (reason == null || reason.trim().isEmpty) return;
            await service.stopOrder(
              order: order,
              performer: user,
              reason: reason,
            );
          case 'resume':
            await service.resumeOrder(order: order, performer: user);
          case 'reopen':
            await service.reopenOrder(order: order, performer: user);
          case 'priority':
            final priority = await _pickPriority(context);
            if (priority == null) return;
            await service.changePriority(
              order: order,
              performer: user,
              priority: priority,
            );
          case 'reassign':
            final department = await _pickDepartment(context);
            if (department == null) return;
            await service.reassignDepartment(
              order: order,
              performer: user,
              department: department,
            );
          case 'time':
            await _showDepartmentTimes(context, ref, order);
        }
        onChanged();
      },
      itemBuilder: (context) => [
        if (!order.isStopped)
          const PopupMenuItem(value: 'stop', child: Text('Stop Order'))
        else
          const PopupMenuItem(value: 'resume', child: Text('Resume Order')),
        const PopupMenuItem(value: 'priority', child: Text('Change Priority')),
        const PopupMenuItem(value: 'reassign', child: Text('Reassign Department')),
        const PopupMenuItem(
          value: 'time',
          child: Text('Department Time'),
        ),
        if (order.status == OrderStatus.completed ||
            order.status == OrderStatus.cancelled)
          const PopupMenuItem(value: 'reopen', child: Text('Reopen Order')),
      ],
    );
  }

  Future<String?> _promptText(
    BuildContext context, {
    required String title,
    required String label,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<OrderPriority?> _pickPriority(BuildContext context) {
    return showDialog<OrderPriority>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Priority'),
        children: [
          for (final priority in OrderPriority.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, priority),
              child: Text(priority.label),
            ),
        ],
      ),
    );
  }

  Future<Department?> _pickDepartment(BuildContext context) {
    return showDialog<Department>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Department'),
        children: [
          for (final department in Department.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, department),
              child: Text(department.label),
            ),
        ],
      ),
    );
  }

  Future<void> _showDepartmentTimes(
    BuildContext context,
    WidgetRef ref,
    ProductionOrder order,
  ) async {
    final analytics = ref.read(analyticsServiceProvider);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Time in Departments · ${order.orderNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final department in Department.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${department.label}: '
                  '${analytics.departmentHours(order, department).toStringAsFixed(1)} h',
                ),
              ),
          ],
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
