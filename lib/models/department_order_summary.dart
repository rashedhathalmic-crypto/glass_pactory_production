import 'enums/department.dart';

class DepartmentOrderSummary {
  const DepartmentOrderSummary({
    required this.department,
    required this.activeCount,
    required this.pendingCount,
    required this.completedCount,
  });

  final Department department;
  final int activeCount;
  final int pendingCount;
  final int completedCount;

  int get total => activeCount + pendingCount + completedCount;
}
