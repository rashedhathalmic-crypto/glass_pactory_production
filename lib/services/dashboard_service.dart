import '../models/dashboard_stats.dart';
import '../models/department_order_summary.dart';
import '../models/report_summary.dart';
import '../models/enums/department.dart';
import '../models/enums/department_stage_status.dart';
import '../models/enums/inspection_status.dart';
import '../models/enums/order_status.dart';
import '../core/helpers/department_stats_helper.dart';
import 'production_order_repository.dart';
import 'user_repository.dart';

class DashboardService {
  DashboardService(this._orderRepository, this._userRepository);

  final ProductionOrderRepository _orderRepository;
  final UserRepository _userRepository;

  Future<DashboardStats> loadStats({
    required DateTime asOf,
    required List<DepartmentOrderSummary> departmentSummaries,
  }) async {
    final results = await Future.wait([
      _orderRepository.countTotalOrders(),
      _orderRepository.countOverdueOrders(asOf: asOf),
      _userRepository.countActiveUsers(),
    ]);

    final totalOrders = results[0];
    final overdue = results[1];
    final activeUsers = results[2];

    final inProgress = DepartmentStatsHelper.sumStatus(
      departmentSummaries,
      (summary) => summary.activeCount,
    );
    final onHold = DepartmentStatsHelper.sumStatus(
      departmentSummaries,
      (summary) => summary.pendingCount,
    );
    final completed = DepartmentStatsHelper.sumStatus(
      departmentSummaries,
      (summary) => summary.completedCount,
    );

    final departmentCounts = {
      for (final summary in departmentSummaries)
        summary.department: summary.activeCount + summary.pendingCount,
    };

    return DashboardStats(
      totalOrders: totalOrders,
      inProgressOrders: inProgress,
      completedOrders: completed,
      onHoldOrders: onHold,
      overdueOrders: overdue,
      activeUsers: activeUsers,
      departmentCounts: departmentCounts,
      recentOrders: departmentSummaries,
    );
  }

  Future<ReportSummary> generateReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final orders = await _orderRepository.getOrdersForReport(
      startDate: startDate,
      endDate: endDate,
    );

    final completed = orders.where((o) => o.status == OrderStatus.completed);
    final total = orders.length;
    final completedCount = completed.length;

    final completionRate = total == 0 ? 0.0 : (completedCount / total) * 100;

    double totalCycleDays = 0;
    int cycleCount = 0;
    for (final order in completed) {
      if (order.startedAt != null && order.completedAt != null) {
        totalCycleDays +=
            order.completedAt!.difference(order.startedAt!).inHours / 24;
        cycleCount++;
      }
    }
    final averageCycleDays = cycleCount == 0
        ? 0.0
        : totalCycleDays / cycleCount;

    final inspected = orders.where(
      (o) =>
          o.inspectionStatus == InspectionStatus.passed ||
          o.inspectionStatus == InspectionStatus.failed,
    );
    final passed = orders
        .where((o) => o.inspectionStatus == InspectionStatus.passed)
        .length;
    final inspectionPassRate = inspected.isEmpty
        ? 0.0
        : (passed / inspected.length) * 100;

    final departmentThroughput = <Department, int>{};
    for (final dept in Department.values) {
      departmentThroughput[dept] = orders
          .where(
            (o) => o.stageStatusFor(dept) == DepartmentStageStatus.completed,
          )
          .length;
    }

    final statusBreakdown = <OrderStatus, int>{};
    for (final status in OrderStatus.values) {
      statusBreakdown[status] = orders.where((o) => o.status == status).length;
    }

    final periodLabel = _formatPeriod(startDate, endDate);

    return ReportSummary(
      periodLabel: periodLabel,
      totalProduced: completedCount,
      completionRate: completionRate,
      averageCycleDays: averageCycleDays,
      inspectionPassRate: inspectionPassRate,
      departmentThroughput: departmentThroughput,
      statusBreakdown: statusBreakdown,
    );
  }

  String _formatPeriod(DateTime? start, DateTime? end) {
    if (start == null && end == null) return 'All Time';
    if (start != null && end != null) {
      return '${start.toLocal().toString().split(' ').first} — ${end.toLocal().toString().split(' ').first}';
    }
    if (start != null) {
      return 'From ${start.toLocal().toString().split(' ').first}';
    }
    return 'Until ${end!.toLocal().toString().split(' ').first}';
  }
}