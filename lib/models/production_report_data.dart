import 'enums/department.dart';
import 'production_order.dart';

class ProductionReportData {
  const ProductionReportData({
    required this.title,
    required this.periodLabel,
    this.summaryRows = const [],
    this.orders = const [],
    this.departmentRows = const {},
    this.productionTimeRows = const [],
  });

  final String title;
  final String periodLabel;
  final List<ReportRow> summaryRows;
  final List<ProductionOrder> orders;
  final Map<Department, int> departmentRows;
  final List<ProductionTimeRow> productionTimeRows;
}

class ReportRow {
  const ReportRow({required this.label, required this.value});

  final String label;
  final String value;
}

class ProductionTimeRow {
  const ProductionTimeRow({
    required this.orderNumber,
    required this.department,
    required this.hours,
  });

  final String orderNumber;
  final Department department;
  final double hours;
}
