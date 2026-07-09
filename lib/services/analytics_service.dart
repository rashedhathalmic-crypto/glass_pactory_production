import 'package:intl/intl.dart';

import '../models/enums/delivery_status.dart';
import '../models/enums/department.dart';
import '../models/enums/order_status.dart';
import '../models/enums/order_type.dart';
import '../models/dashboard_stats.dart';
import '../models/extended_dashboard_stats.dart';
import '../models/order_history_entry.dart';
import '../models/production_order.dart';
import 'history_service.dart';
import 'production_order_repository.dart';

class AnalyticsService {
  AnalyticsService(this._orderRepository, this._historyService);

  final ProductionOrderRepository _orderRepository;
  final HistoryService _historyService;

  Future<List<ProductionOrder>> _fetchOrders() =>
      _orderRepository.getAllOrders(limit: 500);

  bool _isToday(DateTime date, DateTime asOf) {
    return date.year == asOf.year &&
        date.month == asOf.month &&
        date.day == asOf.day;
  }

  bool _isSameWeek(DateTime date, DateTime asOf) {
    final start = asOf.subtract(Duration(days: asOf.weekday - 1));
    final weekStart = DateTime(start.year, start.month, start.day);
    final weekEnd = weekStart.add(const Duration(days: 7));
    return !date.isBefore(weekStart) && date.isBefore(weekEnd);
  }

  bool _isSameMonth(DateTime date, DateTime asOf) {
    return date.year == asOf.year && date.month == asOf.month;
  }

  bool _isDelayed(ProductionOrder order, DateTime asOf) {
    final due = order.dueDate;
    if (due == null) return false;
    if (order.status == OrderStatus.completed ||
        order.status == OrderStatus.cancelled) {
      return false;
    }
    return due.isBefore(asOf);
  }

  Map<DeliveryStatus, int> _deliverySummary(List<ProductionOrder> orders) {
    final summary = {
      for (final status in DeliveryStatus.values) status: 0,
    };
    for (final order in orders) {
      final delivery = order.workflowFor(Department.finishedDelivery);
      summary[delivery.deliveryStatus] =
          (summary[delivery.deliveryStatus] ?? 0) + 1;
    }
    return summary;
  }

  List<ChartPoint> _dailyProduction(List<ProductionOrder> orders, DateTime asOf) {
    final formatter = DateFormat('EEE');
    final points = <ChartPoint>[];
    for (var i = 6; i >= 0; i--) {
      final day = DateTime(asOf.year, asOf.month, asOf.day)
          .subtract(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));
      final count = orders.where((order) {
        final completed = order.completedAt;
        return completed != null &&
            !completed.isBefore(day) &&
            completed.isBefore(nextDay);
      }).length;
      points.add(ChartPoint(label: formatter.format(day), value: count.toDouble()));
    }
    return points;
  }

  List<ChartPoint> _monthlyProduction(
    List<ProductionOrder> orders,
    DateTime asOf,
  ) {
    final formatter = DateFormat('MMM');
    final points = <ChartPoint>[];
    for (var i = 5; i >= 0; i--) {
      final month = DateTime(asOf.year, asOf.month - i, 1);
      final nextMonth = DateTime(month.year, month.month + 1, 1);
      final count = orders.where((order) {
        final completed = order.completedAt;
        return completed != null &&
            !completed.isBefore(month) &&
            completed.isBefore(nextMonth);
      }).length;
      points.add(
        ChartPoint(label: formatter.format(month), value: count.toDouble()),
      );
    }
    return points;
  }

  List<DepartmentChartPoint> _departmentProduction(
    List<ProductionOrder> orders,
  ) {
    return Department.values.map((department) {
      final count = orders.where((order) {
        if (order.status == OrderStatus.completed ||
            order.status == OrderStatus.cancelled) {
          return false;
        }
        return order.currentDepartment == department;
      }).length;
      return DepartmentChartPoint(department: department, value: count.toDouble());
    }).toList();
  }

  List<ChartPoint> _reworkTrend(List<ProductionOrder> orders, DateTime asOf) {
    final formatter = DateFormat('MMM');
    final points = <ChartPoint>[];
    for (var i = 5; i >= 0; i--) {
      final month = DateTime(asOf.year, asOf.month - i, 1);
      final nextMonth = DateTime(month.year, month.month + 1, 1);
      final count = orders.where((order) {
        if (order.orderType != OrderType.rework) return false;
        final created = order.createdAt;
        return created != null &&
            !created.isBefore(month) &&
            created.isBefore(nextMonth);
      }).length;
      points.add(
        ChartPoint(label: formatter.format(month), value: count.toDouble()),
      );
    }
    return points;
  }

  Future<ExtendedDashboardStats> buildExtendedStats({
    required DateTime asOf,
    required DashboardStats phase1Stats,
    List<ProductionOrder>? recentOrders,
    List<OrderHistoryEntry>? recentActivities,
  }) async {
    final orders = await _fetchOrders();
    final activities =
        recentActivities ?? await _historyService.getRecentHistory(limit: 15);
    final recent = recentOrders ?? orders.take(10).toList();

    var todaysOrders = 0;
    var thisWeekOrders = 0;
    var thisMonthOrders = 0;
    var delayedOrders = 0;
    var reworkOrders = 0;

    for (final order in orders) {
      final created = order.createdAt;
      if (created != null) {
        if (_isToday(created, asOf)) todaysOrders++;
        if (_isSameWeek(created, asOf)) thisWeekOrders++;
        if (_isSameMonth(created, asOf)) thisMonthOrders++;
      }
      if (_isDelayed(order, asOf)) delayedOrders++;
      if (order.orderType == OrderType.rework) reworkOrders++;
    }

    return ExtendedDashboardStats(
      phase1: phase1Stats,
      todaysOrders: todaysOrders,
      thisWeekOrders: thisWeekOrders,
      thisMonthOrders: thisMonthOrders,
      delayedOrders: delayedOrders,
      reworkOrders: reworkOrders,
      deliverySummary: _deliverySummary(orders),
      dailyProduction: _dailyProduction(orders, asOf),
      monthlyProduction: _monthlyProduction(orders, asOf),
      departmentProduction: _departmentProduction(orders),
      reworkTrend: _reworkTrend(orders, asOf),
      recentActivities: activities,
      recentOrders: recent,
    );
  }

  double departmentHours(ProductionOrder order, Department department) {
    final workflow = order.workflowFor(department);
    final start = workflow.workStartedAt;
    final end = workflow.finishedAt ?? DateTime.now();
    if (start == null) return 0;
    return end.difference(start).inMinutes / 60.0;
  }

  List<ProductionOrder> delayedOrdersList(
    List<ProductionOrder> orders,
    DateTime asOf,
  ) {
    return orders.where((order) => _isDelayed(order, asOf)).toList();
  }

  List<ProductionOrder> reworkOrdersList(List<ProductionOrder> orders) {
    return orders
        .where((order) => order.orderType == OrderType.rework)
        .toList();
  }
}
