import '../../models/enums/department.dart';
import '../../models/production_order.dart';

/// Optional context for department- or order-scoped permission checks.
class PermissionContext {
  const PermissionContext({
    this.department,
    this.targetDepartment,
    this.order,
  });

  final Department? department;
  final Department? targetDepartment;
  final ProductionOrder? order;

  Department? get effectiveDepartment =>
      department ?? order?.currentDepartment;
}
