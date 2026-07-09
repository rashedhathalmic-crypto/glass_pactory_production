import '../../core/permissions/app_permission.dart';
import '../../core/permissions/permission_context.dart';
import '../../core/permissions/permission_policy.dart';
import '../../models/app_user.dart';
import '../../models/enums/department.dart';
import '../../models/enums/user_role.dart';

extension UserRoleExtensions on UserRole {
  bool canManageUsers() =>
      PermissionPolicy.evaluate(_systemUser(this), AppPermission.manageUsers);

  bool canManageOrders() =>
      PermissionPolicy.evaluate(_systemUser(this), AppPermission.createOrders);

  bool canViewReports() =>
      PermissionPolicy.evaluate(_systemUser(this), AppPermission.viewReports);

  bool canViewManagement() =>
      PermissionPolicy.evaluate(_systemUser(this), AppPermission.viewManagement);

  bool canSendNotifications() => PermissionPolicy.evaluate(
        _systemUser(this),
        AppPermission.sendNotifications,
      );

  bool canSendDepartmentNotifications() => PermissionPolicy.evaluate(
        _systemUser(this),
        AppPermission.sendDepartmentNotifications,
      );

  bool canViewAuditLog() =>
      PermissionPolicy.evaluate(_systemUser(this), AppPermission.viewAuditLog);

  bool canManageProduction() =>
      PermissionPolicy.evaluate(_systemUser(this), AppPermission.manageProduction);

  bool canStopResumeOrders() =>
      PermissionPolicy.evaluate(_systemUser(this), AppPermission.stopResumeOrders);

  bool canDeleteOrders() =>
      PermissionPolicy.evaluate(_systemUser(this), AppPermission.deleteOrders);

  bool canReopenOrders() =>
      PermissionPolicy.evaluate(_systemUser(this), AppPermission.reopenOrders);

  bool canChangePriorities() =>
      PermissionPolicy.evaluate(_systemUser(this), AppPermission.changePriorities);

  bool canReassignDepartments() => PermissionPolicy.evaluate(
        _systemUser(this),
        AppPermission.reassignDepartments,
      );

  bool canSystemSettings() =>
      PermissionPolicy.evaluate(_systemUser(this), AppPermission.systemSettings);
}

extension AppUserPermissions on AppUser {
  bool hasPermission(
    AppPermission permission, {
    PermissionContext? context,
  }) =>
      PermissionPolicy.evaluate(this, permission, context: context);

  bool canAccessDepartment(Department department) =>
      PermissionPolicy.canAccessDepartment(this, department);
}

AppUser _systemUser(UserRole role) => AppUser(
      uid: '',
      email: '',
      displayName: '',
      role: role,
      isActive: true,
    );
