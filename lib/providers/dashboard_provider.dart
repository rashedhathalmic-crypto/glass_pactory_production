import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard_stats.dart';
import '../models/dashboard_stats_request.dart';
import '../models/department_order_summary.dart';
import '../models/enums/department.dart';
import '../models/report_period.dart';
import '../models/report_summary.dart';
import '../services/dashboard_service.dart';
import 'production_order_provider.dart';
import 'user_provider.dart';

final dashboardServiceProvider = Provider<DashboardService>((ref) {
  return DashboardService(
    ref.read(productionOrderRepositoryProvider),
    ref.read(userRepositoryProvider),
  );
});

/// Shared department workload snapshot — one Firestore query for all departments.
final departmentOrderSummariesProvider =
    FutureProvider<List<DepartmentOrderSummary>>((ref) async {
      return ref
          .read(productionOrderRepositoryProvider)
          .fetchDepartmentOrderSummaries();
    });

/// Derived from [departmentOrderSummariesProvider] — no extra Firestore reads.
final departmentActiveCountsProvider = Provider<AsyncValue<Map<Department, int>>>(
  (ref) {
    return ref.watch(departmentOrderSummariesProvider).whenData(
      (summaries) => {
        for (final summary in summaries)
          summary.department: summary.activeCount + summary.pendingCount,
      },
    );
  },
);

/// Dashboard statistics keyed by a frozen [DashboardStatsRequest.asOf].
final dashboardStatsProvider =
    FutureProvider.family<DashboardStats, DashboardStatsRequest>((ref, request) async {
      final departmentSummaries = await ref.watch(
        departmentOrderSummariesProvider.future,
      );

      return ref.read(dashboardServiceProvider).loadStats(
        asOf: request.asOf,
        departmentSummaries: departmentSummaries,
      );
    });

final reportSummaryProvider = FutureProvider.family<ReportSummary, ReportPeriod>(
  (ref, period) async {
    return ref.read(dashboardServiceProvider).generateReport(
      startDate: period.startDate,
      endDate: period.endDate,
    );
  },
);
