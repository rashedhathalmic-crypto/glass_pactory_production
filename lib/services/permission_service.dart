import '../../models/app_user.dart';
import '../../models/enums/user_role.dart';
import '../../utils/exceptions/permission_exception.dart';
import '../core/permissions/app_permission.dart';
import '../core/permissions/permission_context.dart';
import '../core/permissions/permission_policy.dart';

/// Service-layer permission enforcement.
class PermissionService {
  const PermissionService();

  bool can(
    AppUser user,
    AppPermission permission, {
    PermissionContext? context,
  }) =>
      PermissionPolicy.evaluate(user, permission, context: context);

  void require(
    AppUser user,
    AppPermission permission, {
    PermissionContext? context,
  }) {
    if (!can(user, permission, context: context)) {
      throw PermissionException(PermissionPolicy.denialMessage(permission));
    }
  }

  void requireDepartmentAccess(
    AppUser user,
    PermissionContext context,
  ) {
    final dept = context.effectiveDepartment;
    if (dept == null) {
      throw const PermissionException('Access denied: department is required.');
    }
    if (!PermissionPolicy.canAccessDepartment(user, dept)) {
      throw PermissionException(
        'Access denied: you cannot access ${dept.label}.',
      );
    }
  }

  void requireOrderAccess(AppUser user, PermissionContext context) {
    final order = context.order;
    if (order == null) {
      throw const PermissionException('Access denied: order is required.');
    }

    if (user.role == UserRole.admin || user.role == UserRole.manager) {
      return;
    }

    if (user.role == UserRole.operator) {
      require(
        user,
        AppPermission.viewAssignedOrders,
        context: context,
      );
      return;
    }

    requireDepartmentAccess(user, context);
  }
}
