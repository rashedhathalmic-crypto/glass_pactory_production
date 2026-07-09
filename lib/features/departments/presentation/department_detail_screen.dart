import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/helpers/date_helper.dart';
import '../../../core/helpers/responsive_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/enums/department.dart';
import '../../../models/enums/order_status.dart';
import '../../../models/production_order.dart';
import '../../../routing/route_paths.dart';
import '../../../providers/production_order_provider.dart';
import '../../../models/enums/inspection_status.dart';
import '../../../core/theme/app_icons.dart';
import '../../../widgets/widgets.dart';

class DepartmentDetailScreen extends ConsumerWidget {
  const DepartmentDetailScreen({super.key, required this.department});

  final Department department;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(departmentOrdersStreamProvider(department));

    return Scaffold(
      appBar: AppBar(
        title: Text(department.label),
        leading: IconButton(
          icon: const Icon(AppIcons.arrowBack),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: ResponsiveHelper.pagePadding(context),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DepartmentHeroIllustration(department: department),
                if (department == Department.glassProcessing)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.infoBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(AppIcons.departments, size: 20, color: AppColors.info),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'New orders start here. Review drawings and PDF/DXF files, then transfer to Grinding & Washing.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (department == Department.assemblyAutoclave)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.infoBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(AppIcons.quality, size: 20, color: AppColors.info),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Optional inspection, quantities, and photos can be recorded before advancing to Quality.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ordersAsync.when(
                  skipLoadingOnReload: true,
                  loading: () => const AppLoadingIndicator(),
                  error: (e, _) => AppErrorView(message: e.toString()),
                  data: (orders) {
                    if (orders.isEmpty) {
                      return AppEmptyState(
                        title: 'No active orders in ${department.label}',
                        subtitle:
                            'Orders will appear here when they reach this department.',
                      );
                    }
                    return AppCard(
                      title: 'Active Orders (${orders.length})',
                      child: Column(
                        children: orders
                            .map((o) => _OrderRow(order: o))
                            .toList(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final ProductionOrder order;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(RoutePaths.orderDetailPath(order.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderNumber,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${order.customerName} · ${order.glassType}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  if (order.currentDepartment == Department.assemblyAutoclave &&
                      order.inspectionStatus != InspectionStatus.notStarted)
                    Text(
                      'Inspection: ${order.inspectionStatus.label}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  _WorkStatusLabel(order: order),
                ],
              ),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusChip(
                    label: order.status.label,
                    tone: order.status == OrderStatus.onHold
                        ? StatusTone.warning
                        : StatusTone.info,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Due ${DateHelper.formatDate(order.dueDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(AppIcons.arrowForward, size: 18),
          ],
        ),
      ),
    );
  }
}

class _WorkStatusLabel extends StatelessWidget {
  const _WorkStatusLabel({required this.order});

  final ProductionOrder order;

  @override
  Widget build(BuildContext context) {
    final workflow = order.workflowFor(order.currentDepartment);
    String label;
    if (order.status == OrderStatus.onHold) {
      label = 'On Hold';
    } else if (workflow.paused) {
      label = 'Paused';
    } else if (workflow.workStarted) {
      label = 'In Progress';
    } else {
      label = 'Not Started';
    }
    return Text(
      'Work: $label',
      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
    );
  }
}
