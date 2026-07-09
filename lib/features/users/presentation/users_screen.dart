import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/validators.dart';
import '../../../core/helpers/responsive_helper.dart';
import '../../../core/theme/app_icons.dart';
import '../../../models/app_user.dart';
import '../../../core/permissions/permission_policy.dart';
import '../../../models/enums/department.dart';
import '../../../models/enums/user_role.dart';
import '../../../providers/user_provider.dart';
import '../../../utils/exceptions/exceptions.dart';
import '../../../utils/extensions/extensions.dart';
import '../../../widgets/widgets.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersStreamProvider);

    return SingleChildScrollView(
      padding: ResponsiveHelper.pagePadding(context),
      child: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'User Management',
              subtitle: 'Manage factory personnel and access roles',
              actions: [
                ElevatedButton.icon(
                  onPressed: () => _showUserForm(context, ref),
                  icon: const Icon(AppIcons.add, size: 18),
                  label: const Text('Add User'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            usersAsync.when(
              skipLoadingOnReload: true,
              loading: () => const AppLoadingIndicator(),
              error: (e, _) => AppErrorView(message: e.toString()),
              data: (users) {
                if (users.isEmpty) {
                  return AppEmptyState(
                    title: 'No users found',
                    action: ElevatedButton(
                      onPressed: () => _showUserForm(context, ref),
                      child: const Text('Create First User'),
                    ),
                  );
                }
                return AppCard(
                  child: _UsersTable(
                    users: users,
                    onEdit: (user) => _showUserForm(context, ref, user: user),
                    onToggleActive: (user) => _toggleActive(context, ref, user),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    try {
      await ref
          .read(userRepositoryProvider)
          .setUserActiveStatus(user.uid, !user.isActive);
      if (context.mounted) {
        context.showAppSnackBar(
          user.isActive ? 'User deactivated' : 'User activated',
        );
      }
    } on AppException catch (e) {
      if (context.mounted) context.showAppSnackBar(e.message, isError: true);
    }
  }

  void _showUserForm(BuildContext context, WidgetRef ref, {AppUser? user}) {
    showDialog(
      context: context,
      builder: (_) => _UserFormDialog(user: user),
    );
  }
}

class _UsersTable extends StatelessWidget {
  const _UsersTable({
    required this.users,
    required this.onEdit,
    required this.onToggleActive,
  });

  final List<AppUser> users;
  final void Function(AppUser user) onEdit;
  final void Function(AppUser user) onToggleActive;

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isMobile(context)) {
      return Column(
        children: users
            .map(
              (user) => _UserTile(
                user: user,
                onEdit: () => onEdit(user),
                onToggleActive: () => onToggleActive(user),
              ),
            )
            .toList(),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Department')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Actions')),
        ],
        rows: users.map((user) {
          return DataRow(
            cells: [
              DataCell(Text(user.displayName)),
              DataCell(Text(user.email)),
              DataCell(Text(user.role.label)),
              DataCell(Text(user.department?.label ?? '—')),
              DataCell(
                StatusChip(
                  label: user.isActive ? 'Active' : 'Inactive',
                  tone: user.isActive ? StatusTone.success : StatusTone.neutral,
                ),
              ),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(AppIcons.edit, size: 18),
                      onPressed: () => onEdit(user),
                    ),
                    IconButton(
                      icon: Icon(
                        user.isActive ? AppIcons.pause : AppIcons.play,
                        size: 18,
                      ),
                      onPressed: () => onToggleActive(user),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.onEdit,
    required this.onToggleActive,
  });

  final AppUser user;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(user.displayName),
      subtitle: Text('${user.role.label} · ${user.email}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusChip(
            label: user.isActive ? 'Active' : 'Inactive',
            tone: user.isActive ? StatusTone.success : StatusTone.neutral,
          ),
          IconButton(icon: const Icon(AppIcons.edit), onPressed: onEdit),
        ],
      ),
      onTap: onToggleActive,
    );
  }
}

class _UserFormDialog extends ConsumerStatefulWidget {
  const _UserFormDialog({this.user});

  final AppUser? user;

  @override
  ConsumerState<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends ConsumerState<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late UserRole _role;
  Department? _department;
  bool _isActive = true;
  bool _isLoading = false;

  bool get isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.displayName);
    _emailController = TextEditingController(text: widget.user?.email);
    _passwordController = TextEditingController();
    _role = widget.user?.role ?? UserRole.operator;
    _department = widget.user?.department;
    _isActive = widget.user?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_role.requiresDepartment) {
      final fixed = _role.fixedDepartment;
      if (fixed != null) {
        _department = fixed;
      } else if (_department == null ||
          !_role.assignableDepartments.contains(_department)) {
        _department = _role.assignableDepartments.first;
      }
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(userRepositoryProvider);

      if (isEditing) {
        final updated = widget.user!.copyWith(
          displayName: _nameController.text.trim(),
          role: _role,
          department: _department,
          isActive: _isActive,
          clearDepartment: _department == null,
        );
        await repo.updateUser(updated);
      } else {
        await repo.createUser(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _nameController.text,
          role: _role,
          department: _department?.name,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        context.showAppSnackBar(isEditing ? 'User updated' : 'User created');
      }
    } on AppException catch (e) {
      if (mounted) context.showAppSnackBar(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? 'Edit User' : 'Create User'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (v) => Validators.displayName(v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: Validators.email,
                  enabled: !isEditing,
                ),
                if (!isEditing) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: Validators.password,
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<UserRole>(
                  isExpanded: true,
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: UserRole.values
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(r.label, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _role = v!;
                    if (!_role.requiresDepartment) {
                      _department = null;
                    } else {
                      _department = _role.fixedDepartment ??
                          (_role.assignableDepartments.contains(_department)
                              ? _department
                              : _role.assignableDepartments.first);
                    }
                  }),
                ),
                if (_role.requiresDepartment) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Department>(
                    isExpanded: true,
                    initialValue: _department,
                    decoration: const InputDecoration(labelText: 'Department'),
                    items: _role.assignableDepartments
                        .map(
                          (d) => DropdownMenuItem(
                            value: d,
                            child: Text(
                              d.shortLabel,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _role.fixedDepartment != null
                        ? null
                        : (v) => setState(() => _department = v),
                  ),
                ],
                if (isEditing) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
