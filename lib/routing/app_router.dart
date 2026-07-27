import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/permissions/permission_policy.dart';
import '../features/audit/presentation/audit_log_screen.dart';
import '../features/authentication/presentation/access_denied_screen.dart';
import '../features/authentication/presentation/login_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/departments/presentation/department_detail_screen.dart';
import '../features/departments/presentation/departments_screen.dart';
import '../features/drawings/presentation/drawing_archive_screen.dart';
import '../features/management/presentation/management_dashboard_screen.dart';
import '../features/management/presentation/production_management_screen.dart';
import '../features/nc_generator/presentation/nc_generator_screen.dart';
import '../features/notifications/presentation/notification_center_screen.dart';
import '../features/production_orders/presentation/order_detail_screen.dart';
import '../features/production_orders/presentation/order_form_screen.dart';
import '../features/production_orders/presentation/orders_list_screen.dart';
import '../features/qr/presentation/qr_scan_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/search/presentation/global_search_screen.dart';
import '../features/users/presentation/users_screen.dart';
import '../models/enums/department.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_shell.dart';
import 'route_paths.dart';
import 'router_refresh.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

String? _guardRoute(Ref ref, String location) {
  final user = ref.read(currentAppUserProvider).asData?.value;
  if (user == null) return null;
  if (location == RoutePaths.accessDenied) return null;
  if (!PermissionPolicy.canAccessRoute(user, location)) {
    return RoutePaths.accessDenied;
  }
  return null;
}

/// GoRouter is created once. Auth changes trigger redirect via [RouterRefresh],
/// not by recreating the router (which would destroy all page state).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefresh(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RoutePaths.dashboard,
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.asData?.value != null;
      final isLoggingIn = state.matchedLocation == RoutePaths.login;
      final location = state.matchedLocation;

      if (!isLoggedIn && !isLoggingIn) return RoutePaths.login;
      if (isLoggedIn && isLoggingIn) return RoutePaths.dashboard;

      return _guardRoute(ref, location);
    },
    routes: [
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.accessDenied,
        builder: (context, state) => AccessDeniedScreen(
          message: state.uri.queryParameters['message'],
        ),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.dashboard,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: RoutePaths.orders,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: OrdersListScreen()),
            routes: [
              GoRoute(
                path: 'create',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const OrderFormScreen(),
              ),
              GoRoute(
                path: ':orderId',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final orderId = state.pathParameters['orderId']!;
                  return OrderDetailScreen(orderId: orderId);
                },
              ),
            ],
          ),
          GoRoute(
            path: RoutePaths.users,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: UsersScreen()),
          ),
          GoRoute(
            path: RoutePaths.departments,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DepartmentsScreen()),
            routes: [
              GoRoute(
                path: ':departmentId',
                parentNavigatorKey: _rootNavigatorKey,
                redirect: (context, state) {
                  final deptId = state.pathParameters['departmentId']!;
                  final department = Department.fromString(deptId);
                  if (deptId != department.name) {
                    return RoutePaths.departmentDetailPath(department.name);
                  }
                  return null;
                },
                builder: (context, state) {
                  final deptId = state.pathParameters['departmentId']!;
                  final department = Department.fromString(deptId);
                  return DepartmentDetailScreen(department: department);
                },
              ),
            ],
          ),
          GoRoute(
            path: RoutePaths.reports,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ReportsScreen()),
          ),
          GoRoute(
            path: RoutePaths.search,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: GlobalSearchScreen()),
          ),
          GoRoute(
            path: RoutePaths.drawings,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DrawingArchiveScreen()),
          ),
          GoRoute(
            path: RoutePaths.notifications,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: NotificationCenterScreen()),
          ),
          GoRoute(
            path: RoutePaths.qrScan,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: QrScanScreen()),
          ),
          GoRoute(
            path: RoutePaths.management,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ManagementDashboardScreen()),
          ),
          GoRoute(
            path: RoutePaths.productionManagement,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProductionManagementScreen()),
          ),
          GoRoute(
            path: RoutePaths.auditLog,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AuditLogScreen()),
          ),
          GoRoute(
            path: RoutePaths.ncGenerator,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: NcGeneratorScreen()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.uri}'))),
  );
});
