import 'department_order_summary.dart';
import 'enums/department.dart';

class DashboardStats {
  const DashboardStats({
    this.totalOrders = 0,
    this.inProgressOrders = 0,
    this.completedOrders = 0,
    this.onHoldOrders = 0,
    this.overdueOrders = 0,
    this.activeUsers = 0,
    this.departmentCounts = const {},
    this.recentOrders = const [],
  });

  final int totalOrders;
  final int inProgressOrders;
  final int completedOrders;
  final int onHoldOrders;
  final int overdueOrders;
  final int activeUsers;
  final Map<Department, int> departmentCounts;
  final List<DepartmentOrderSummary> recentOrders;
}
