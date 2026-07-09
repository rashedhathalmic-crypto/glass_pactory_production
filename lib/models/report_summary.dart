import 'enums/department.dart';
import 'enums/order_status.dart';

class ReportSummary {
  const ReportSummary({
    this.periodLabel = '',
    this.totalProduced = 0,
    this.completionRate = 0,
    this.averageCycleDays = 0,
    this.inspectionPassRate = 0,
    this.departmentThroughput = const {},
    this.statusBreakdown = const {},
  });

  final String periodLabel;
  final int totalProduced;
  final double completionRate;
  final double averageCycleDays;
  final double inspectionPassRate;
  final Map<Department, int> departmentThroughput;
  final Map<OrderStatus, int> statusBreakdown;
}
