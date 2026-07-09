import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/permissions/app_permission.dart';
import '../core/permissions/permission_context.dart';
import '../models/app_user.dart';
import '../services/permission_service.dart';
import 'auth_provider.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return const PermissionService();
});

final currentPermissionsProvider = Provider<CurrentUserPermissions?>((ref) {
  final user = ref.watch(currentAppUserProvider).asData?.value;
  if (user == null) return null;
  return CurrentUserPermissions(user, ref.read(permissionServiceProvider));
});

class CurrentUserPermissions {
  CurrentUserPermissions(this.user, this._service);

  final AppUser user;
  final PermissionService _service;

  bool can(AppPermission permission, {PermissionContext? context}) =>
      _service.can(user, permission, context: context);

  void require(AppPermission permission, {PermissionContext? context}) =>
      _service.require(user, permission, context: context);
}
