import '../../models/app_user.dart';
import '../../models/enums/department.dart';
import '../../models/enums/user_role.dart';
import 'app_permission.dart';
import 'permission_context.dart';

/// Central RBAC policy — all role/permission decisions flow through here.
abstract final class PermissionPolicy {
  static const _adminPermissions = AppPermission.values;

  static const _managerPermissions = {
    AppPermission.viewDashboard,
    AppPermission.viewAllOrders,
    AppPermission.createOrders,
    AppPermission.editOrders,
    AppPermission.reopenOrders,
    AppPermission.changePriorities,
    AppPermission.reassignDepartments,
    AppPermission.manageProduction,
    AppPermission.stopResumeOrders,
    AppPermission.viewReports,
    AppPermission.viewManagement,
    AppPermission.sendNotifications,
    AppPermission.viewDepartmentOrders,
    AppPermission.startWork,
    AppPermission.pauseWork,
    AppPermission.resumeWork,
    AppPermission.finishDepartment,
    AppPermission.transferOrders,
    AppPermission.reviewOperators,
    AppPermission.addNotes,
    AppPermission.printQr,
  };

  static const _supervisorPermissions = {
    AppPermission.viewDashboard,
    AppPermission.viewDepartmentOrders,
    AppPermission.startWork,
    AppPermission.pauseWork,
    AppPermission.resumeWork,
    AppPermission.finishDepartment,
    AppPermission.transferOrders,
    AppPermission.reviewOperators,
    AppPermission.sendDepartmentNotifications,
    AppPermission.addNotes,
    AppPermission.printQr,
  };

  static const _operatorPermissions = {
    AppPermission.viewDashboard,
    AppPermission.viewAssignedOrders,
    AppPermission.startWork,
    AppPermission.pauseWork,
    AppPermission.resumeWork,
    AppPermission.finishDepartment,
    AppPermission.addNotes,
    AppPermission.printQr,
  };

  static const _qualityInspectorPermissions = {
    AppPermission.viewDashboard,
    AppPermission.viewDepartmentOrders,
    AppPermission.startWork,
    AppPermission.pauseWork,
    AppPermission.resumeWork,
    AppPermission.finishDepartment,
    AppPermission.transferOrders,
    AppPermission.addNotes,
    AppPermission.finalInspection,
    AppPermission.passRejectInspection,
    AppPermission.addInspectionPhotos,
    AppPermission.signInspection,
    AppPermission.createRework,
    AppPermission.printQr,
  };

  static const _warehousePermissions = {
    AppPermission.viewDashboard,
    AppPermission.viewDepartmentOrders,
    AppPermission.startWork,
    AppPermission.pauseWork,
    AppPermission.resumeWork,
    AppPermission.finishOrders,
    AppPermission.updateDeliveryStatus,
    AppPermission.printLabels,
    AppPermission.printQr,
    AppPermission.customerDeliveryConfirmation,
    AppPermission.addNotes,
  };

  static bool evaluate(
    AppUser user,
    AppPermission permission, {
    PermissionContext? context,
  }) {
    if (!user.isActive) return false;

    if (!_roleGrantsPermission(user.role, permission)) return false;

    return _contextAllows(user, permission, context);
  }

  static bool _roleGrantsPermission(UserRole role, AppPermission permission) {
  return switch (role) {
      UserRole.admin => _adminPermissions.contains(permission),
      UserRole.manager => _managerPermissions.contains(permission),
      UserRole.supervisor => _supervisorPermissions.contains(permission),
      UserRole.operator => _operatorPermissions.contains(permission),
      UserRole.qualityInspector =>
        _qualityInspectorPermissions.contains(permission),
      UserRole.warehouseDelivery => _warehousePermissions.contains(permission),
    };
  }

  static bool _contextAllows(
    AppUser user,
    AppPermission permission,
    PermissionContext? context,
  ) {
    if (user.role == UserRole.admin || user.role == UserRole.manager) {
      return _managerContextAllows(user, permission, context);
    }

    if (user.role.isDepartmentScoped) {
      return _departmentScopedContextAllows(user, permission, context);
    }

    return true;
  }

  static bool _managerContextAllows(
    AppUser user,
    AppPermission permission,
    PermissionContext? context,
  ) {
    if (permission == AppPermission.transferOrders &&
        context?.targetDepartment != null &&
        user.role == UserRole.manager) {
      return true;
    }
    return true;
  }

  static bool _departmentScopedContextAllows(
    AppUser user,
    AppPermission permission,
    PermissionContext? context,
  ) {
    final userDept = user.department;
    if (userDept == null) return false;

    if (!_roleMatchesDepartment(user)) return false;

    final targetDept = context?.effectiveDepartment;
    if (targetDept != null && targetDept != userDept) {
      return false;
    }

    if (permission == AppPermission.viewAssignedOrders) {
      if (user.role != UserRole.operator) {
        return permission != AppPermission.viewAssignedOrders;
      }
      final order = context?.order;
      if (order == null) return true;
      if (order.currentDepartment != userDept) return false;
      final assignedId = order.assignedOperatorId;
      return assignedId == null || assignedId == user.uid;
    }

    if (permission == AppPermission.transferOrders && context != null) {
      final order = context.order;
      final target = context.targetDepartment;
      if (order != null && target != null) {
        final next = order.currentDepartment.next;
        return next == target;
      }
    }

    if (permission == AppPermission.createRework) {
      return user.role == UserRole.qualityInspector &&
          userDept == Department.quality;
    }

    return true;
  }

  static bool _roleMatchesDepartment(AppUser user) {
    final dept = user.department;
    if (dept == null) return false;

    return switch (user.role) {
      UserRole.qualityInspector => dept == Department.quality,
      UserRole.warehouseDelivery => dept == Department.finishedDelivery,
      UserRole.operator =>
        dept != Department.quality && dept != Department.finishedDelivery,
      UserRole.supervisor => true,
      _ => true,
    };
  }

  static bool canAccessDepartment(AppUser user, Department department) {
    if (user.role == UserRole.admin || user.role == UserRole.manager) {
      return true;
    }
    if (!user.role.isDepartmentScoped) return false;
    if (user.department != department) return false;
    return _roleMatchesDepartment(user);
  }

  static bool canAccessRoute(AppUser user, String location) {
    if (location.startsWith('/users')) {
      return evaluate(user, AppPermission.manageUsers);
    }
    if (location.startsWith('/reports')) {
      return evaluate(user, AppPermission.viewReports);
    }
    if (location == '/management' || location.startsWith('/management/')) {
      return evaluate(user, AppPermission.viewManagement);
    }
    if (location.startsWith('/production-management')) {
      return evaluate(user, AppPermission.manageProduction);
    }
    if (location.startsWith('/audit-log')) {
      return evaluate(user, AppPermission.viewAuditLog);
    }
    if (location.startsWith('/orders/create')) {
      return evaluate(user, AppPermission.createOrders);
    }
    if (location.startsWith('/departments/')) {
      final deptId = location.split('/').elementAtOrNull(2);
      if (deptId == null) return true;
      final department = Department.fromString(deptId);
      return canAccessDepartment(user, department);
    }
  return true;
  }

  static String denialMessage(AppPermission permission) {
    return 'Access denied: you do not have permission to '
        '${_permissionLabel(permission)}.';
  }

  static String _permissionLabel(AppPermission permission) {
    return switch (permission) {
      AppPermission.manageUsers => 'manage users',
      AppPermission.manageDepartments => 'manage departments',
      AppPermission.viewDashboard => 'view the dashboard',
      AppPermission.viewAllOrders => 'view all orders',
      AppPermission.createOrders => 'create orders',
      AppPermission.editOrders => 'edit orders',
      AppPermission.deleteOrders => 'delete orders',
      AppPermission.reopenOrders => 'reopen orders',
      AppPermission.changePriorities => 'change priorities',
      AppPermission.reassignDepartments => 'reassign departments',
      AppPermission.manageProduction => 'manage production',
      AppPermission.stopResumeOrders => 'stop or resume orders',
      AppPermission.viewReports => 'view reports',
      AppPermission.viewManagement => 'view management',
      AppPermission.viewAuditLog => 'view the audit log',
      AppPermission.sendNotifications => 'send notifications',
      AppPermission.sendDepartmentNotifications =>
        'send department notifications',
      AppPermission.systemSettings => 'change system settings',
      AppPermission.viewDepartmentOrders => 'view department orders',
      AppPermission.viewAssignedOrders => 'view assigned orders',
      AppPermission.startWork => 'start work',
      AppPermission.pauseWork => 'pause work',
      AppPermission.resumeWork => 'resume work',
      AppPermission.finishDepartment => 'finish department work',
      AppPermission.transferOrders => 'transfer orders',
      AppPermission.reviewOperators => 'review operators',
      AppPermission.addNotes => 'add notes',
      AppPermission.finalInspection => 'perform final inspection',
      AppPermission.passRejectInspection => 'pass or reject inspection',
      AppPermission.addInspectionPhotos => 'add inspection photos',
      AppPermission.signInspection => 'sign inspection',
      AppPermission.createRework => 'create rework orders',
      AppPermission.finishOrders => 'finish orders',
      AppPermission.updateDeliveryStatus => 'update delivery status',
      AppPermission.printLabels => 'print labels',
      AppPermission.printQr => 'print QR codes',
      AppPermission.customerDeliveryConfirmation =>
        'confirm customer delivery',
    };
  }
}

extension UserRoleScope on UserRole {
  bool get isDepartmentScoped => switch (this) {
        UserRole.supervisor ||
        UserRole.operator ||
        UserRole.qualityInspector ||
        UserRole.warehouseDelivery =>
          true,
        _ => false,
      };

  bool get requiresDepartment => isDepartmentScoped;

  Department? get fixedDepartment => switch (this) {
        UserRole.qualityInspector => Department.quality,
        UserRole.warehouseDelivery => Department.finishedDelivery,
        _ => null,
      };

  List<Department> get assignableDepartments => switch (this) {
        UserRole.qualityInspector => [Department.quality],
        UserRole.warehouseDelivery => [Department.finishedDelivery],
        UserRole.supervisor || UserRole.operator => [
            Department.glassProcessing,
            Department.grindingWashing,
            Department.assemblyAutoclave,
          ],
        _ => Department.values,
      };
}
