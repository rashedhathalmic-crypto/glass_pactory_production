import 'package:flutter_test/flutter_test.dart';
import 'package:glass_pactory_production/models/dashboard_stats_request.dart';

void main() {
  group('provider stability helpers', () {
    test('DashboardStatsRequest equality is stable for provider caching', () {
      final asOf = DateTime(2026, 7, 9, 12, 0, 0, 123);
      final a = DashboardStatsRequest(asOf);
      final b = DashboardStatsRequest(asOf);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('DashboardStatsRequest changes only when asOf changes', () {
      final first = DashboardStatsRequest(DateTime(2026, 7, 9, 12));
      final second = DashboardStatsRequest(DateTime(2026, 7, 9, 13));

      expect(first, isNot(equals(second)));
    });
  });
}
