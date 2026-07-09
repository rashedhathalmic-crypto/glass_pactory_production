import 'package:flutter_test/flutter_test.dart';
import 'package:glass_pactory_production/core/helpers/department_stats_helper.dart';
import 'package:glass_pactory_production/models/enums/department.dart';
import 'package:glass_pactory_production/models/enums/order_status.dart';
import 'package:glass_pactory_production/models/production_order.dart';

ProductionOrder _order({
  required String id,
  required OrderStatus status,
  required Department department,
}) {
  return ProductionOrder.fromMap(id, {
    'orderNumber': 'GF-$id',
    'customerName': 'Customer $id',
    'glassType': 'Clear',
    'drawingNumber': 'D$id',
    'thicknessMm': 10,
    'quantity': 1,
    'polygonSides': 4,
    'polygonSideLengthsMm': [100, 100, 100, 100],
    'status': status.name,
    'currentDepartment': department.name,
    'departmentStatuses': {},
    'createdAt': DateTime(2026),
    'updatedAt': DateTime(2026),
    'createdBy': 'u1',
  });
}

void main() {
  test('summarizeByDepartment groups orders in one pass', () {
    final orders = [
      _order(id: '1', status: OrderStatus.inProgress, department: Department.glassProcessing),
      _order(id: '2', status: OrderStatus.onHold, department: Department.glassProcessing),
      _order(id: '3', status: OrderStatus.completed, department: Department.quality),
    ];

    final summaries = DepartmentStatsHelper.summarizeByDepartment(orders);
    final glassProcessing =
        summaries.firstWhere((s) => s.department == Department.glassProcessing);
    final quality = summaries.firstWhere((s) => s.department == Department.quality);

    expect(glassProcessing.activeCount, 1);
    expect(glassProcessing.pendingCount, 1);
    expect(glassProcessing.completedCount, 0);
    expect(quality.completedCount, 1);

    expect(
      DepartmentStatsHelper.sumStatus(summaries, (s) => s.activeCount),
      1,
    );
    expect(
      DepartmentStatsHelper.sumStatus(summaries, (s) => s.pendingCount),
      1,
    );
    expect(
      DepartmentStatsHelper.sumStatus(summaries, (s) => s.completedCount),
      1,
    );
  });
}
