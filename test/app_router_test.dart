import 'package:flutter_test/flutter_test.dart';
import 'package:glass_pactory_production/routing/app_router.dart';
import 'package:glass_pactory_production/routing/route_paths.dart';

void main() {
  group('public routes', () {
    test('NC Generator is public', () {
      expect(isPublicRoute(RoutePaths.ncGenerator), isTrue);
    });

    test('no other application route gets the NC Generator exemption', () {
      const protectedRoutes = <String>[
        RoutePaths.login,
        RoutePaths.accessDenied,
        RoutePaths.dashboard,
        RoutePaths.orders,
        RoutePaths.users,
        RoutePaths.departments,
        RoutePaths.reports,
        RoutePaths.search,
        RoutePaths.drawings,
        RoutePaths.notifications,
        RoutePaths.qrScan,
        RoutePaths.management,
        RoutePaths.productionManagement,
        RoutePaths.auditLog,
      ];

      for (final route in protectedRoutes) {
        expect(
          isPublicRoute(route),
          isFalse,
          reason: '$route must not get the NC Generator exemption',
        );
      }
    });

    test('the public route exemption is an exact match', () {
      expect(isPublicRoute('${RoutePaths.ncGenerator}/other'), isFalse);
    });
  });
}
