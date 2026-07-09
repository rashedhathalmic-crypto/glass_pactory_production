import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/permissions/permission_policy.dart';
import '../../../core/helpers/responsive_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/enums/department.dart';
import '../../../providers/auth_provider.dart';
import '../../../routing/route_paths.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../widgets/widgets.dart';

class DepartmentsScreen extends ConsumerWidget {
  const DepartmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(departmentActiveCountsProvider);
    final user = ref.watch(currentAppUserProvider).asData?.value;
    final padding = ResponsiveHelper.pagePadding(context);
    final columns = ResponsiveHelper.departmentGridColumns(context);
    final departments = Department.values
        .where(
          (dept) =>
              user == null || PermissionPolicy.canAccessDepartment(user, dept),
        )
        .toList();

    return SingleChildScrollView(
      padding: padding,
      child: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Departments',
              subtitle: 'Navigate production floor operations by department',
            ),
            const SizedBox(height: 24),
            countsAsync.when(
              skipLoadingOnReload: true,
              loading: () => const AppLoadingIndicator(),
              error: (e, _) => AppErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(departmentOrderSummariesProvider),
              ),
              data: (counts) {
                return ResponsiveCardGrid(
                  columns: columns,
                  itemCount: departments.length,
                  itemBuilder: (context, index) {
                    final dept = departments[index];
                    final activeCount = counts[dept] ?? 0;

                    return _DepartmentCard(
                      department: dept,
                      activeCount: activeCount,
                      onTap: () => context.push(
                        RoutePaths.departmentDetailPath(dept.name),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({
    required this.department,
    required this.activeCount,
    required this.onTap,
  });

  final Department department;
  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DepartmentCardIllustration(department: department),
              Text(
                department.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$activeCount active orders',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              if (department == Department.assemblyAutoclave) ...[
                const SizedBox(height: 4),
                const Text(
                  'Optional inspection available',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
