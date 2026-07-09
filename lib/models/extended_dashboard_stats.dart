import 'dashboard_stats.dart';
import 'enums/delivery_status.dart';
import 'enums/department.dart';
import 'order_history_entry.dart';
import 'production_order.dart';

class ExtendedDashboardStats {
  const ExtendedDashboardStats({
    required this.phase1,
    this.todaysOrders = 0,
    this.thisWeekOrders = 0,
    this.thisMonthOrders = 0,
    this.delayedOrders = 0,
    this.reworkOrders = 0,
    this.deliverySummary = const {},
    this.dailyProduction = const [],
    this.monthlyProduction = const [],
    this.departmentProduction = const [],
    this.reworkTrend = const [],
    this.recentActivities = const [],
    this.recentOrders = const [],
  });

  final DashboardStats phase1;
  final int todaysOrders;
  final int thisWeekOrders;
  final int thisMonthOrders;
  final int delayedOrders;
  final int reworkOrders;
  final Map<DeliveryStatus, int> deliverySummary;
  final List<ChartPoint> dailyProduction;
  final List<ChartPoint> monthlyProduction;
  final List<DepartmentChartPoint> departmentProduction;
  final List<ChartPoint> reworkTrend;
  final List<OrderHistoryEntry> recentActivities;
  final List<ProductionOrder> recentOrders;
}

class ChartPoint {
  const ChartPoint({required this.label, required this.value});

  final String label;
  final double value;
}

class DepartmentChartPoint {
  const DepartmentChartPoint({
    required this.department,
    required this.value,
  });

  final Department department;
  final double value;
}
