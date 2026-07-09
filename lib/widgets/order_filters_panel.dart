import 'package:flutter/material.dart';

import '../models/enums/department.dart';
import '../models/enums/message_priority.dart';
import '../models/enums/message_type.dart';
import '../models/enums/order_priority.dart';
import '../models/enums/order_status.dart';
import '../models/enums/recipient_scope.dart';
import '../models/order_filters.dart';

class OrderFiltersPanel extends StatelessWidget {
  const OrderFiltersPanel({
    super.key,
    required this.filters,
    required this.onChanged,
    this.onClear,
  });

  final OrderFilters filters;
  final ValueChanged<OrderFilters> onChanged;
  final VoidCallback? onClear;

  static const double _spacing = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final fieldWidth = _resolveFieldWidth(maxWidth);

        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _field(
              width: fieldWidth,
              child: TextFormField(
                initialValue: filters.customer,
                decoration: const InputDecoration(
                  labelText: 'Customer',
                  isDense: true,
                ),
                onChanged: (value) =>
                    onChanged(filters.copyWith(customer: value)),
              ),
            ),
            _field(
              width: fieldWidth,
              child: TextFormField(
                initialValue: filters.project,
                decoration: const InputDecoration(
                  labelText: 'Project',
                  isDense: true,
                ),
                onChanged: (value) =>
                    onChanged(filters.copyWith(project: value)),
              ),
            ),
            _field(
              width: fieldWidth,
              child: TextFormField(
                initialValue: filters.glassType,
                decoration: const InputDecoration(
                  labelText: 'Glass Type',
                  isDense: true,
                ),
                onChanged: (value) =>
                    onChanged(filters.copyWith(glassType: value)),
              ),
            ),
            _field(
              width: fieldWidth,
              child: DropdownButtonFormField<Department?>(
                key: ValueKey('dept-${filters.department}'),
                isExpanded: true,
                initialValue: filters.department,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  for (final dept in Department.values)
                    DropdownMenuItem(
                      value: dept,
                      child: Text(
                        dept.shortLabel,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                selectedItemBuilder: (context) => [
                  const Text('All', overflow: TextOverflow.ellipsis),
                  for (final dept in Department.values)
                    Text(
                      dept.shortLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
                onChanged: (value) => onChanged(
                  filters.copyWith(
                    department: value,
                    clearDepartment: value == null,
                  ),
                ),
              ),
            ),
            _field(
              width: fieldWidth,
              child: DropdownButtonFormField<OrderStatus?>(
                key: ValueKey('status-${filters.status}'),
                isExpanded: true,
                initialValue: filters.status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  for (final status in OrderStatus.values)
                    DropdownMenuItem(
                      value: status,
                      child: Text(
                        status.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => onChanged(
                  filters.copyWith(status: value, clearStatus: value == null),
                ),
              ),
            ),
            _field(
              width: fieldWidth,
              child: DropdownButtonFormField<OrderPriority?>(
                key: ValueKey('priority-${filters.priority}'),
                isExpanded: true,
                initialValue: filters.priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  for (final priority in OrderPriority.values)
                    DropdownMenuItem(
                      value: priority,
                      child: Text(
                        priority.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => onChanged(
                  filters.copyWith(
                    priority: value,
                    clearPriority: value == null,
                  ),
                ),
              ),
            ),
            if (onClear != null && filters.hasActiveFilters)
              TextButton(onPressed: onClear, child: const Text('Clear Filters')),
          ],
        );
      },
    );
  }

  static double _resolveFieldWidth(double maxWidth) {
    if (maxWidth >= 1200) return 200;
    if (maxWidth >= 900) return 180;
    if (maxWidth >= 640) return (maxWidth - _spacing) / 2;
    return maxWidth;
  }

  static Widget _field({required double width, required Widget child}) {
    return SizedBox(width: width, child: child);
  }
}

class MessageComposeFields extends StatelessWidget {
  const MessageComposeFields({
    super.key,
    required this.titleController,
    required this.messageController,
    required this.type,
    required this.priority,
    required this.scope,
    required this.onTypeChanged,
    required this.onPriorityChanged,
    required this.onScopeChanged,
    this.department,
    this.onDepartmentChanged,
    this.receiverName,
    this.onReceiverNameChanged,
    this.includeMaintenanceType = false,
  });

  final TextEditingController titleController;
  final TextEditingController messageController;
  final MessageType type;
  final MessagePriority priority;
  final RecipientScope scope;
  final ValueChanged<MessageType> onTypeChanged;
  final ValueChanged<MessagePriority> onPriorityChanged;
  final ValueChanged<RecipientScope> onScopeChanged;
  final Department? department;
  final ValueChanged<Department?>? onDepartmentChanged;
  final String? receiverName;
  final ValueChanged<String>? onReceiverNameChanged;
  final bool includeMaintenanceType;

  @override
  Widget build(BuildContext context) {
    final types = MessageType.values
        .where(
          (value) =>
              includeMaintenanceType ||
              value != MessageType.maintenanceNotice,
        )
        .toList();

    return Column(
      children: [
        TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: messageController,
          decoration: const InputDecoration(labelText: 'Message'),
          maxLines: 4,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<MessageType>(
          key: ValueKey('type-$type'),
          isExpanded: true,
          initialValue: type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [
            for (final item in types)
              DropdownMenuItem(
                value: item,
                child: Text(item.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) {
            if (value != null) onTypeChanged(value);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<MessagePriority>(
          key: ValueKey('priority-$priority'),
          isExpanded: true,
          initialValue: priority,
          decoration: const InputDecoration(labelText: 'Priority'),
          items: [
            for (final item in MessagePriority.values)
              DropdownMenuItem(
                value: item,
                child: Text(item.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) {
            if (value != null) onPriorityChanged(value);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<RecipientScope>(
          key: ValueKey('scope-$scope'),
          isExpanded: true,
          initialValue: scope,
          decoration: const InputDecoration(labelText: 'Recipients'),
          items: [
            for (final item in RecipientScope.values)
              DropdownMenuItem(
                value: item,
                child: Text(item.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) {
            if (value != null) onScopeChanged(value);
          },
        ),
        if (scope == RecipientScope.singleEmployee) ...[
          const SizedBox(height: 12),
          TextFormField(
            initialValue: receiverName,
            decoration: const InputDecoration(labelText: 'Employee Name'),
            onChanged: onReceiverNameChanged,
          ),
        ],
        if (scope == RecipientScope.department &&
            onDepartmentChanged != null) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<Department?>(
            key: ValueKey('compose-dept-$department'),
            isExpanded: true,
            initialValue: department,
            decoration: const InputDecoration(labelText: 'Department'),
            items: [
              for (final dept in Department.values)
                DropdownMenuItem(
                  value: dept,
                  child: Text(dept.shortLabel, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onDepartmentChanged,
          ),
        ],
      ],
    );
  }
}
