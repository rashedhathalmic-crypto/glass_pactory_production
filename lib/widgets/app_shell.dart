import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/helpers/responsive_helper.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_theme.dart';
import '../core/permissions/permission_policy.dart';
import '../models/app_user.dart';
import '../models/enums/audit_action.dart';
import '../providers/auth_provider.dart';
import '../providers/phase2_providers.dart';
import '../routing/route_paths.dart';
import '../utils/extensions/extensions.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentAppUserProvider);
    final location = GoRouterState.of(context).uri.path;
    final isDesktop = ResponsiveHelper.isDesktop(context);

    return userAsync.when(
      skipLoadingOnReload: true,
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) =>
          const Scaffold(body: Center(child: Text('Failed to load session'))),
      data: (user) {
        if (user == null) return child;

        if (isDesktop) {
          return _DesktopShell(user: user, location: location, child: child);
        }
        return _MobileShell(user: user, location: location, child: child);
      },
    );
  }
}

class _DesktopShell extends ConsumerWidget {
  const _DesktopShell({
    required this.user,
    required this.location,
    required this.child,
  });

  final AppUser user;
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = _buildDestinations(user);

    return Scaffold(
      body: Row(
        children: [
          _SideNavigation(
            user: user,
            location: location,
            destinations: destinations,
            expanded: true,
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(user: user),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileShell extends ConsumerWidget {
  const _MobileShell({
    required this.user,
    required this.location,
    required this.child,
  });

  final AppUser user;
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = _buildDestinations(user);
    final drawerKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: drawerKey,
      appBar: AppBar(
        title: Text(_titleForLocation(location)),
        leading: IconButton(
          icon: const Icon(AppIcons.menu),
          onPressed: () => drawerKey.currentState?.openDrawer(),
        ),
      ),
      drawer: Drawer(
        child: _SideNavigation(
          user: user,
          location: location,
          destinations: destinations,
          expanded: false,
          inDrawer: true,
        ),
      ),
      body: child,
    );
  }
}

class _SideNavigation extends ConsumerWidget {
  const _SideNavigation({
    required this.user,
    required this.location,
    required this.destinations,
    required this.expanded,
    this.inDrawer = false,
  });

  final AppUser user;
  final String location;
  final List<_NavDestination> destinations;
  final bool expanded;
  final bool inDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Glass Factory',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: expanded ? 18 : 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Production ERP',
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final dest in destinations)
                _NavItem(
                  destination: dest,
                  selected: _isSelected(location, dest.path),
                  expanded: expanded,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.role.label,
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () async {
                  await ref.read(auditServiceProvider).log(
                        action: AuditAction.logout,
                        performedBy: user.uid,
                        performedByName: user.displayName,
                        entityType: 'user',
                        entityId: user.uid,
                      );
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) context.go(RoutePaths.login);
                },
                icon: const Icon(AppIcons.logout, size: 18),
                label: const Text('Sign Out'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (inDrawer) {
      return Container(color: AppColors.darkBlue, child: content);
    }

    return Container(
      width: expanded ? 260 : 72,
      color: AppColors.darkBlue,
      child: content,
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.expanded,
  });

  final _NavDestination destination;
  final bool selected;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.darkBlueLight : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: InkWell(
          onTap: () => context.go(destination.path),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  destination.icon,
                  size: 20,
                  color: selected
                      ? AppColors.white
                      : AppColors.white.withValues(alpha: 0.65),
                ),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      destination.label,
                      style: TextStyle(
                        color: selected
                            ? AppColors.white
                            : AppColors.white.withValues(alpha: 0.65),
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final unreadAsync = ref.watch(unreadNotificationsCountProvider);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _titleForLocation(location),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                unreadAsync.when(
                  data: (count) => IconButton(
                    tooltip: 'Notifications',
                    onPressed: () => context.go(RoutePaths.notifications),
                    icon: Badge(
                      isLabelVisible: count > 0,
                      label: Text('$count'),
                      child: const Icon(AppIcons.notifications),
                    ),
                  ),
                  loading: () => IconButton(
                    onPressed: () => context.go(RoutePaths.notifications),
                    icon: const Icon(AppIcons.notifications),
                  ),
                  error: (_, _) => IconButton(
                    onPressed: () => context.go(RoutePaths.notifications),
                    icon: const Icon(AppIcons.notifications),
                  ),
                ),
                Flexible(
                  child: Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.lightGray,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(
                      user.role.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.path,
    required this.label,
    required this.icon,
  });

  final String path;
  final String label;
  final IconData icon;
}

List<_NavDestination> _buildDestinations(AppUser user) {
  final role = user.role;
  final destinations = <_NavDestination>[
    const _NavDestination(
      path: RoutePaths.dashboard,
      label: 'Dashboard',
      icon: AppIcons.dashboard,
    ),
    const _NavDestination(
      path: RoutePaths.orders,
      label: 'Production Orders',
      icon: AppIcons.orders,
    ),
  ];

  if (role.isDepartmentScoped && user.department != null) {
    destinations.add(
      _NavDestination(
        path: RoutePaths.departmentDetailPath(user.department!.name),
        label: user.department!.label,
        icon: AppIcons.departments,
      ),
    );
  } else {
    destinations.add(
      const _NavDestination(
        path: RoutePaths.departments,
        label: 'Departments',
        icon: AppIcons.departments,
      ),
    );
  }

  destinations.addAll(const [
    _NavDestination(
      path: RoutePaths.search,
      label: 'Search',
      icon: AppIcons.search,
    ),
    _NavDestination(
      path: RoutePaths.drawings,
      label: 'Drawings',
      icon: AppIcons.archive,
    ),
    _NavDestination(
      path: RoutePaths.qrScan,
      label: 'QR Scan',
      icon: AppIcons.qr,
    ),
    _NavDestination(
      path: RoutePaths.notifications,
      label: 'Notifications',
      icon: AppIcons.notifications,
    ),
  ]);

  if (role.canViewManagement()) {
    destinations.add(
      const _NavDestination(
        path: RoutePaths.management,
        label: 'Management',
        icon: AppIcons.management,
      ),
    );
    destinations.add(
      const _NavDestination(
        path: RoutePaths.productionManagement,
        label: 'Production Mgmt',
        icon: AppIcons.play,
      ),
    );
  }

  if (role.canManageUsers()) {
    destinations.add(
      const _NavDestination(
        path: RoutePaths.users,
        label: 'Users',
        icon: AppIcons.users,
      ),
    );
  }

  if (role.canViewReports()) {
    destinations.add(
      const _NavDestination(
        path: RoutePaths.reports,
        label: 'Reports',
        icon: AppIcons.reports,
      ),
    );
  }

  if (role.canViewAuditLog()) {
    destinations.add(
      const _NavDestination(
        path: RoutePaths.auditLog,
        label: 'Audit Log',
        icon: AppIcons.audit,
      ),
    );
  }

  return destinations;
}

bool _isSelected(String location, String path) {
  if (path == RoutePaths.dashboard) return location == path;
  return location.startsWith(path);
}

String _titleForLocation(String location) {
  if (location.startsWith(RoutePaths.orders)) return 'Production Orders';
  if (location.startsWith(RoutePaths.users)) return 'Users';
  if (location.startsWith(RoutePaths.departments)) return 'Departments';
  if (location.startsWith(RoutePaths.reports)) return 'Reports';
  if (location.startsWith(RoutePaths.search)) return 'Global Search';
  if (location.startsWith(RoutePaths.drawings)) return 'Drawing Archive';
  if (location.startsWith(RoutePaths.notifications)) return 'Notifications';
  if (location.startsWith(RoutePaths.qrScan)) return 'QR Scanner';
  if (location.startsWith(RoutePaths.management)) return 'Management';
  if (location.startsWith(RoutePaths.productionManagement)) {
    return 'Production Management';
  }
  if (location.startsWith(RoutePaths.auditLog)) return 'Audit Log';
  return 'Dashboard';
}
