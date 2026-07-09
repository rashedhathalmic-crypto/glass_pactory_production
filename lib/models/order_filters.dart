import 'enums/department.dart';
import 'enums/order_priority.dart';
import 'enums/order_status.dart';

class OrderFilters {
  const OrderFilters({
    this.customer = '',
    this.project = '',
    this.glassType = '',
    this.department,
    this.status,
    this.priority,
    this.startDate,
    this.endDate,
  });

  final String customer;
  final String project;
  final String glassType;
  final Department? department;
  final OrderStatus? status;
  final OrderPriority? priority;
  final DateTime? startDate;
  final DateTime? endDate;

  bool get hasActiveFilters =>
      customer.isNotEmpty ||
      project.isNotEmpty ||
      glassType.isNotEmpty ||
      department != null ||
      status != null ||
      priority != null ||
      startDate != null ||
      endDate != null;

  OrderFilters copyWith({
    String? customer,
    String? project,
    String? glassType,
    Department? department,
    OrderStatus? status,
    OrderPriority? priority,
    DateTime? startDate,
    DateTime? endDate,
    bool clearDepartment = false,
    bool clearStatus = false,
    bool clearPriority = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return OrderFilters(
      customer: customer ?? this.customer,
      project: project ?? this.project,
      glassType: glassType ?? this.glassType,
      department: clearDepartment ? null : (department ?? this.department),
      status: clearStatus ? null : (status ?? this.status),
      priority: clearPriority ? null : (priority ?? this.priority),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OrderFilters &&
      customer == other.customer &&
      project == other.project &&
      glassType == other.glassType &&
      department == other.department &&
      status == other.status &&
      priority == other.priority &&
      startDate == other.startDate &&
      endDate == other.endDate;

  @override
  int get hashCode => Object.hash(
        customer,
        project,
        glassType,
        department,
        status,
        priority,
        startDate,
        endDate,
      );
}
