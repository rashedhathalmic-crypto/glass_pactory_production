import 'package:flutter_test/flutter_test.dart';
import 'package:glass_pactory_production/core/permissions/app_permission.dart';
import 'package:glass_pactory_production/core/permissions/permission_context.dart';
import 'package:glass_pactory_production/core/permissions/permission_policy.dart';
import 'package:glass_pactory_production/models/app_user.dart';
import 'package:glass_pactory_production/models/enums/department.dart';
import 'package:glass_pactory_production/models/enums/user_role.dart';
import 'package:glass_pactory_production/models/production_order.dart';
import 'package:glass_pactory_production/models/enums/order_status.dart';

ProductionOrder _order({
  Department department = Department.glassProcessing,
  String? assignedOperatorId,
}) {
  return ProductionOrder(
    id: 'order-1',
    orderNumber: 'ORD-001',
    customerName: 'Customer',
    glassType: 'Tempered',
    drawingNumber: 'DWG-1',
    thicknessMm: 10,
    quantity: 1,
    status: OrderStatus.inProgress,
    currentDepartment: department,
    departmentStatuses: const {},
    assignedOperatorId: assignedOperatorId,
  );
}

AppUser _user({
  required UserRole role,
  Department? department,
  String uid = 'user-1',
}) {
  return AppUser(
    uid: uid,
    email: 'user@test.com',
    displayName: 'Test User',
    role: role,
    department: department,
  );
}

void main() {
  group('PermissionPolicy', () {
    test('admin has full access', () {
      final admin = _user(role: UserRole.admin);
      expect(
        PermissionPolicy.evaluate(admin, AppPermission.manageUsers),
        isTrue,
      );
      expect(
        PermissionPolicy.evaluate(admin, AppPermission.deleteOrders),
        isTrue,
      );
    });

    test('manager cannot manage users or audit log', () {
      final manager = _user(role: UserRole.manager);
      expect(
        PermissionPolicy.evaluate(manager, AppPermission.manageProduction),
        isTrue,
      );
      expect(
        PermissionPolicy.evaluate(manager, AppPermission.manageUsers),
        isFalse,
      );
      expect(
        PermissionPolicy.evaluate(manager, AppPermission.viewAuditLog),
        isFalse,
      );
    });

    test('operator only sees assigned orders in their department', () {
      final operator = _user(
        role: UserRole.operator,
        department: Department.glassProcessing,
      );
      final assigned = _order(assignedOperatorId: operator.uid);
      final other = _order(assignedOperatorId: 'other-user');

      expect(
        PermissionPolicy.evaluate(
          operator,
          AppPermission.viewAssignedOrders,
          context: PermissionContext(order: assigned, department: assigned.currentDepartment),
        ),
        isTrue,
      );
      expect(
        PermissionPolicy.evaluate(
          operator,
          AppPermission.viewAssignedOrders,
          context: PermissionContext(order: other, department: other.currentDepartment),
        ),
        isFalse,
      );
      expect(
        PermissionPolicy.evaluate(operator, AppPermission.transferOrders),
        isFalse,
      );
    });

    test('quality inspector is limited to quality department', () {
      final inspector = _user(
        role: UserRole.qualityInspector,
        department: Department.quality,
      );
      expect(
        PermissionPolicy.canAccessDepartment(inspector, Department.quality),
        isTrue,
      );
      expect(
        PermissionPolicy.canAccessDepartment(
          inspector,
          Department.glassProcessing,
        ),
        isFalse,
      );
      expect(
        PermissionPolicy.evaluate(inspector, AppPermission.createRework),
        isTrue,
      );
    });

    test('warehouse role is limited to finished delivery', () {
      final warehouse = _user(
        role: UserRole.warehouseDelivery,
        department: Department.finishedDelivery,
      );
      expect(
        PermissionPolicy.evaluate(warehouse, AppPermission.finishOrders),
        isTrue,
      );
      expect(
        PermissionPolicy.canAccessDepartment(
          warehouse,
          Department.glassProcessing,
        ),
        isFalse,
      );
    });
  });
}
