import 'package:flutter_test/flutter_test.dart';
import 'package:glass_pactory_production/core/helpers/parse_helpers.dart';
import 'package:glass_pactory_production/models/department_workflow_data.dart';
import 'package:glass_pactory_production/models/enums/department.dart';
import 'package:glass_pactory_production/models/order_material.dart';
import 'package:glass_pactory_production/models/production_order.dart';

void main() {
  test('ParseHelpers handles string numeric values', () {
    expect(ParseHelpers.parseDouble('300'), 300);
    expect(ParseHelpers.parseInt('12'), 12);
    expect(ParseHelpers.parseDoubleList(['300', 200, '150']),
        [300, 200, 150]);
  });

  test('ProductionOrder.fromMap maps legacy department keys to Glass Processing',
      () {
    final order = ProductionOrder.fromMap('order-legacy', {
      'orderNumber': 'GF-2026-00002',
      'customerName': 'Legacy Customer',
      'glassType': 'Tempered',
      'thicknessMm': 10,
      'quantity': 1,
      'status': 'inProgress',
      'currentDepartment': 'cutting',
      'departmentStatuses': {},
    });

    expect(order.currentDepartment, Department.glassProcessing);
  });

  test('ProductionOrder.fromMap parses legacy string thickness and dimensions',
      () {
    final order = ProductionOrder.fromMap('order-1', {
      'orderNumber': 'GF-2026-00001',
      'customerName': 'Test Customer',
      'glassType': 'Tempered',
      'thicknessMm': '300',
      'quantity': '5',
      'widthMm': '1200',
      'heightMm': '800',
      'status': 'inProgress',
      'currentDepartment': 'cutting',
      'departmentStatuses': {},
    });

    expect(order.thicknessMm, 300);
    expect(order.quantity, 5);
    expect(order.currentDepartment, Department.glassProcessing);
    expect(order.areaSqM, closeTo(0.96, 0.001));
    expect(order.polygonSideLengthsMm, [1200, 800, 1200, 800]);
  });

  test('DepartmentWorkflowData parses string qty fields', () {
    final workflow = DepartmentWorkflowData.fromMap({
      'inputQty': '10',
      'passQty': '8',
      'rejectQty': '2',
    });

    expect(workflow.inputQty, 10);
    expect(workflow.passQty, 8);
    expect(workflow.rejectQty, 2);
  });

  test('OrderMaterial parses string quantity', () {
    final material = OrderMaterial.fromMap({
      'name': 'Glass',
      'quantity': '12.5',
      'unit': 'pcs',
    });

    expect(material.quantity, 12.5);
  });
}
