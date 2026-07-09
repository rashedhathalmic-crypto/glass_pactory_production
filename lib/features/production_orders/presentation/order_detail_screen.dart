import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/helpers/date_helper.dart';
import '../../../core/helpers/responsive_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/helpers/order_status_tone_helper.dart';
import '../../../models/enums/department_stage_status.dart';
import '../../../models/enums/inspection_status.dart';
import '../../../core/theme/app_icons.dart';
import '../../../models/app_user.dart';
import '../../../models/enums/department.dart';
import '../../../models/order_history_entry.dart';
import '../../../models/enums/order_status.dart';
import '../../../models/production_order.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/production_order_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/workflow_provider.dart';
import '../../../utils/exceptions/exceptions.dart';
import '../../../core/permissions/app_permission.dart';
import '../../../core/permissions/permission_context.dart';
import '../../../utils/extensions/extensions.dart';
import '../../../widgets/widgets.dart';
import '../../../core/constants/default_materials.dart';
import '../../../core/helpers/open_url_helper.dart';
import '../../../models/order_material.dart';
import 'widgets/department_workflow_panel.dart';
import 'widgets/order_materials_editor.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderStreamProvider(orderId));
    final user = ref.watch(currentAppUserProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: orderAsync.when(
          data: (order) => Text(order?.orderNumber ?? 'Order Detail'),
          loading: () => const Text('Order Detail'),
          error: (_, _) => const Text('Order Detail'),
        ),
        leading: IconButton(
          icon: const Icon(AppIcons.arrowBack),
          onPressed: () => context.pop(),
        ),
      ),
      body: orderAsync.when(
        skipLoadingOnReload: true,
        loading: () => const AppLoadingIndicator(),
        error: (e, _) => AppErrorView(message: e.toString()),
        data: (order) {
          if (order == null) {
            return const AppEmptyState(title: 'Order not found');
          }
          return SingleChildScrollView(
            padding: ResponsiveHelper.pagePadding(context),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OrderHeader(order: order),
                    const SizedBox(height: 20),
                    _WorkflowProgress(order: order),
                    const SizedBox(height: 20),
                    if (user != null)
                      DepartmentWorkflowPanel(order: order, user: user),
                    if (user != null &&
                        user.hasPermission(
                          AppPermission.reviewOperators,
                          context: PermissionContext(
                            order: order,
                            department: order.currentDepartment,
                          ),
                        ))
                      _AssignOperatorCard(order: order, user: user),
                    const SizedBox(height: 20),
                    _OrderDetailsCard(order: order),
                    const SizedBox(height: 20),
                    if (user != null) _OrderMaterialsCard(order: order, user: user),
                    const SizedBox(height: 20),
                    _OrderHistorySection(orderId: orderId),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.order});

  final ProductionOrder order;

  @override
  Widget build(BuildContext context) {
    final isCompact = ResponsiveHelper.isMobile(context);

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          order.customerName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${order.glassType} · ${order.dimensionsLabel} · Qty ${order.quantity}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );

    final status = StatusChip(
      label: order.status.label,
      tone: OrderStatusToneHelper.toneFor(order.status),
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          details,
          const SizedBox(height: 12),
          status,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: details),
        status,
      ],
    );
  }
}

class _WorkflowProgress extends StatelessWidget {
  const _WorkflowProgress({required this.order});

  final ProductionOrder order;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Production Workflow',
      child: Column(
        children: [
          for (final dept in Department.values) ...[
            _DepartmentStep(
              department: dept,
              status: order.stageStatusFor(dept),
              isCurrent: order.currentDepartment == dept,
              inspectionStatus: dept == Department.assemblyAutoclave
                  ? order.inspectionStatus
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _DepartmentStep extends StatelessWidget {
  const _DepartmentStep({
    required this.department,
    required this.status,
    required this.isCurrent,
    this.inspectionStatus,
  });

  final Department department;
  final DepartmentStageStatus status;
  final bool isCurrent;
  final InspectionStatus? inspectionStatus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  department.label,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (inspectionStatus != null &&
                    inspectionStatus != InspectionStatus.notStarted)
                  Text(
                    'Inspection: ${inspectionStatus!.label}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: StatusChip(
                label: isCurrent ? 'Current' : status.label,
                tone: switch (status) {
                  DepartmentStageStatus.completed => StatusTone.success,
                  DepartmentStageStatus.active => StatusTone.info,
                  _ => StatusTone.neutral,
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignOperatorCard extends ConsumerWidget {
  const _AssignOperatorCard({required this.order, required this.user});

  final ProductionOrder order;
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (order.status == OrderStatus.completed ||
        order.status == OrderStatus.cancelled) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: AppCard(
        title: 'Operator Assignment',
        child: OutlinedButton(
          onPressed: () => showDialog(
            context: context,
            builder: (ctx) => _AssignOperatorDialog(order: order, performer: user),
          ),
          child: Text(
            order.assignedOperatorName != null
                ? 'Reassign (${order.assignedOperatorName})'
                : 'Assign Operator',
          ),
        ),
      ),
    );
  }
}

class _AssignOperatorDialog extends ConsumerWidget {
  const _AssignOperatorDialog({required this.order, required this.performer});

  final ProductionOrder order;
  final AppUser performer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<AppUser>>(
      future: ref
          .read(userRepositoryProvider)
          .getOperatorsForDepartment(order.currentDepartment.name),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AlertDialog(
            content: SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final operators = snapshot.data ?? [];
        if (operators.isEmpty) {
          return AlertDialog(
            title: const Text('Assign Operator'),
            content: const Text('No operators available for this department.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        }

        return AlertDialog(
          title: const Text('Assign Operator'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: operators.map((op) {
                return ListTile(
                  title: Text(op.displayName),
                  subtitle: Text(op.role.label),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await ref
                          .read(workflowServiceProvider)
                          .assignOperator(
                            order: order,
                            operator: op,
                            performer: performer,
                          );
                      if (context.mounted) {
                        context.showAppSnackBar(
                          'Assigned to ${op.displayName}',
                        );
                      }
                    } on AppException catch (e) {
                      if (context.mounted) {
                        context.showAppSnackBar(e.message, isError: true);
                      }
                    }
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _OrderDetailsCard extends StatelessWidget {
  const _OrderDetailsCard({required this.order});

  final ProductionOrder order;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Order Information',
      child: Column(
        children: [
          _DetailRow(label: 'Order Number', value: order.orderNumber),
          if (order.orderType.name == 'rework')
            _DetailRow(label: 'Order Type', value: order.orderType.label),
          if (order.parentOrderId != null)
            _DetailRow(label: 'Parent Order', value: order.parentOrderId!),
          _DetailRow(label: 'Drawing Number', value: order.drawingNumber),
          _DetailRow(
            label: 'Polygon',
            value: '${order.polygonSides} sides',
          ),
          _DetailRow(
            label: 'Area',
            value: '${order.areaSqM.toStringAsFixed(2)} m²',
          ),
          _DetailRow(
            label: 'Thickness',
            value: '${order.thicknessMm.toStringAsFixed(1)} mm',
          ),
          if (order.pdfUrl.isNotEmpty)
            _DetailLinkRow(
              label: 'PDF Drawing',
              onTap: () => openExternalUrl(order.pdfUrl),
            ),
          if (order.dxfUrl.isNotEmpty)
            _DetailLinkRow(
              label: 'DXF Drawing',
              onTap: () => openExternalUrl(order.dxfUrl),
            ),
          _DetailRow(label: 'Priority', value: order.priority.label),
          _DetailRow(
            label: 'Assigned To',
            value: order.assignedOperatorName ?? '—',
          ),
          _DetailRow(
            label: 'Due Date',
            value: DateHelper.formatDate(order.dueDate),
          ),
          _DetailRow(
            label: 'Started',
            value: DateHelper.formatDateTime(order.startedAt),
          ),
          _DetailRow(
            label: 'Description',
            value: order.description.isEmpty ? '—' : order.description,
          ),
          if (order.notes.isNotEmpty)
            _DetailRow(label: 'Notes', value: order.notes),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isCompact = ResponsiveHelper.isMobile(context);

    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _DetailLinkRow extends StatelessWidget {
  const _DetailLinkRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCompact = ResponsiveHelper.isMobile(context);

    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            TextButton(onPressed: onTap, child: const Text('Open File')),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(onPressed: onTap, child: const Text('Open File')),
        ],
      ),
    );
  }
}

class _OrderMaterialsCard extends ConsumerStatefulWidget {
  const _OrderMaterialsCard({required this.order, required this.user});

  final ProductionOrder order;
  final AppUser user;

  @override
  ConsumerState<_OrderMaterialsCard> createState() =>
      _OrderMaterialsCardState();
}

class _OrderMaterialsCardState extends ConsumerState<_OrderMaterialsCard> {
  late List<OrderMaterial> _materials;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _materials = widget.order.materials.isEmpty
        ? DefaultMaterials.initialList()
        : List<OrderMaterial>.from(widget.order.materials);
  }

  @override
  void didUpdateWidget(covariant _OrderMaterialsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.materials != widget.order.materials) {
      _materials = widget.order.materials.isEmpty
          ? DefaultMaterials.initialList()
          : List<OrderMaterial>.from(widget.order.materials);
    }
  }

  Future<void> _save() async {
    if (!mounted) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(workflowServiceProvider).updateMaterials(
            order: widget.order,
            performer: widget.user,
            materials: _materials,
          );
      if (mounted) context.showAppSnackBar('Materials saved');
    } on AppException catch (e) {
      if (mounted) context.showAppSnackBar(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.order.status != OrderStatus.completed &&
        widget.order.status != OrderStatus.cancelled;

    return AppCard(
      title: 'Materials',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrderMaterialsEditor(
            key: ValueKey(widget.order.id),
            materials: _materials.isEmpty
                ? widget.order.materials
                : _materials,
            readOnly: !canEdit,
            onChanged: (materials) => setState(() => _materials = materials),
          ),
          if (canEdit) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Materials'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderHistorySection extends ConsumerWidget {
  const _OrderHistorySection({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(orderHistoryStreamProvider(orderId));

    return historyAsync.when(
      skipLoadingOnReload: true,
      loading: () => const AppLoadingIndicator(),
      error: (e, _) => AppErrorView(message: e.toString()),
      data: (history) => AppCard(
        title: 'History Timeline',
        child: history.isEmpty
            ? const Text('No activity recorded')
            : Column(
                children: [
                  for (var i = 0; i < history.length; i++)
                    _HistoryTimelineTile(
                      entry: history[i],
                      isLast: i == history.length - 1,
                    ),
                ],
              ),
      ),
    );
  }
}

class _HistoryTimelineTile extends StatelessWidget {
  const _HistoryTimelineTile({
    required this.entry,
    required this.isLast,
  });

  final OrderHistoryEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.darkBlue,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.action.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${entry.performedByName} · ${DateHelper.formatDateTime(entry.timestamp)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (entry.notes.isNotEmpty)
                    Text(entry.notes, style: const TextStyle(fontSize: 12)),
                  if (entry.toDepartment != null)
                    Text(
                      '→ ${entry.toDepartment!.label}',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
