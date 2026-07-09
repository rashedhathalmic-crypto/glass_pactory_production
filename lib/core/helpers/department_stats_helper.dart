import '../../models/department_order_summary.dart';
import '../../models/enums/department.dart';
import '../../models/enums/order_status.dart';
import '../../models/production_order.dart';

/// Builds per-department workload counts from a single order list.
abstract final class DepartmentStatsHelper {
  static const trackedStatuses = <OrderStatus>[
    OrderStatus.inProgress,
    OrderStatus.onHold,
    OrderStatus.completed,
  ];

  static List<DepartmentOrderSummary> summarizeByDepartment(
    Iterable<ProductionOrder> orders,
  ) {
    final counts = {
      for (final department in Department.values)
        department: {
          for (final status in trackedStatuses) status: 0,
        },
    };

    for (final order in orders) {
      final departmentCounts = counts[order.currentDepartment];
      if (departmentCounts == null) continue;
      if (!departmentCounts.containsKey(order.status)) continue;
      departmentCounts[order.status] = departmentCounts[order.status]! + 1;
    }

    return Department.values.map((department) {
      final statusCounts = counts[department]!;
      return DepartmentOrderSummary(
        department: department,
        activeCount: statusCounts[OrderStatus.inProgress]!,
        pendingCount: statusCounts[OrderStatus.onHold]!,
        completedCount: statusCounts[OrderStatus.completed]!,
      );
    }).toList();
  }

  static int sumStatus(
    List<DepartmentOrderSummary> summaries,
    int Function(DepartmentOrderSummary summary) selector,
  ) {
    return summaries.fold(0, (total, summary) => total + selector(summary));
  }
}
