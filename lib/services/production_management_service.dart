import '../core/permissions/app_permission.dart';
import '../models/app_user.dart';
import '../models/enums/audit_action.dart';
import '../models/enums/department.dart';
import '../models/enums/department_stage_status.dart';
import '../models/enums/history_action.dart';
import '../models/enums/order_priority.dart';
import '../models/enums/order_status.dart';
import '../models/order_history_entry.dart';
import '../models/production_order.dart';
import 'audit_service.dart';
import 'history_service.dart';
import 'permission_service.dart';
import 'production_order_repository.dart';

class ProductionManagementService {
  ProductionManagementService(
    this._orderRepository,
    this._historyService,
    this._auditService, [
    PermissionService permissions = const PermissionService(),
  ]) : _permissions = permissions;

  final ProductionOrderRepository _orderRepository;
  final HistoryService _historyService;
  final AuditService _auditService;
  final PermissionService _permissions;

  Future<List<ProductionOrder>> fetchAllOrders({
    required AppUser performer,
    int limit = 500,
  }) async {
    _permissions.require(performer, AppPermission.manageProduction);
    return _orderRepository.getAllOrders(limit: limit);
  }

  Future<void> stopOrder({
    required ProductionOrder order,
    required AppUser performer,
    required String reason,
  }) async {
    _permissions.require(performer, AppPermission.stopResumeOrders);
    final updated = order.copyWith(
      isStopped: true,
      stopReason: reason.trim(),
      status: OrderStatus.onHold,
      updatedAt: DateTime.now(),
    );
    await _orderRepository.updateOrder(updated);
    await _logHistory(
      order: order,
      action: HistoryAction.workPaused,
      performer: performer,
      notes: 'Stopped: $reason',
    );
    await _auditService.log(
      action: AuditAction.update,
      performedBy: performer.uid,
      performedByName: performer.displayName,
      entityType: 'production_order',
      entityId: order.id,
      notes: 'Order stopped: $reason',
    );
  }

  Future<void> resumeOrder({
    required ProductionOrder order,
    required AppUser performer,
  }) async {
    _permissions.require(performer, AppPermission.stopResumeOrders);
    final updated = order.copyWith(
      isStopped: false,
      stopReason: '',
      status: OrderStatus.inProgress,
      updatedAt: DateTime.now(),
    );
    await _orderRepository.updateOrder(updated);
    await _logHistory(
      order: order,
      action: HistoryAction.workResumed,
      performer: performer,
      notes: 'Production resumed',
    );
    await _auditService.log(
      action: AuditAction.update,
      performedBy: performer.uid,
      performedByName: performer.displayName,
      entityType: 'production_order',
      entityId: order.id,
      notes: 'Order resumed',
    );
  }

  Future<void> changePriority({
    required ProductionOrder order,
    required AppUser performer,
    required OrderPriority priority,
  }) async {
    _permissions.require(performer, AppPermission.changePriorities);
    final updated = order.copyWith(
      priority: priority,
      updatedAt: DateTime.now(),
    );
    await _orderRepository.updateOrder(updated);
    await _logHistory(
      order: order,
      action: HistoryAction.updated,
      performer: performer,
      notes: 'Priority changed to ${priority.label}',
    );
    await _auditService.log(
      action: AuditAction.update,
      performedBy: performer.uid,
      performedByName: performer.displayName,
      entityType: 'production_order',
      entityId: order.id,
      notes: 'Priority changed to ${priority.label}',
    );
  }

  Future<void> reopenOrder({
    required ProductionOrder order,
    required AppUser performer,
  }) async {
    _permissions.require(performer, AppPermission.reopenOrders);
    final statuses = Map<String, String>.from(order.departmentStatuses);
    statuses[order.currentDepartment.name] =
        DepartmentStageStatus.active.name;

    final updated = order.copyWith(
      status: OrderStatus.inProgress,
      completedAt: null,
      isStopped: false,
      stopReason: '',
      departmentStatuses: statuses,
      updatedAt: DateTime.now(),
    );
    await _orderRepository.updateOrder(updated);
    await _logHistory(
      order: order,
      action: HistoryAction.resumed,
      performer: performer,
      notes: 'Order reopened for production',
    );
    await _auditService.log(
      action: AuditAction.update,
      performedBy: performer.uid,
      performedByName: performer.displayName,
      entityType: 'production_order',
      entityId: order.id,
      notes: 'Order reopened',
    );
  }

  Future<void> reassignDepartment({
    required ProductionOrder order,
    required AppUser performer,
    required Department department,
  }) async {
    _permissions.require(performer, AppPermission.reassignDepartments);
    final statuses = Map<String, String>.from(order.departmentStatuses);
    statuses[order.currentDepartment.name] =
        DepartmentStageStatus.pending.name;
    statuses[department.name] = DepartmentStageStatus.active.name;

    final updated = order.copyWith(
      currentDepartment: department,
      departmentStatuses: statuses,
      status: OrderStatus.inProgress,
      updatedAt: DateTime.now(),
    );
    await _orderRepository.updateOrder(updated);
    await _logHistory(
      order: order,
      action: HistoryAction.transferred,
      performer: performer,
      fromDepartment: order.currentDepartment,
      toDepartment: department,
      notes: 'Reassigned to ${department.label}',
    );
    await _auditService.log(
      action: AuditAction.transfer,
      performedBy: performer.uid,
      performedByName: performer.displayName,
      entityType: 'production_order',
      entityId: order.id,
      notes: 'Reassigned to ${department.label}',
    );
  }

  Future<void> _logHistory({
    required ProductionOrder order,
    required HistoryAction action,
    required AppUser performer,
    Department? fromDepartment,
    Department? toDepartment,
    String notes = '',
  }) async {
    await _historyService.logEntry(
      OrderHistoryEntry(
        id: '',
        orderId: order.id,
        action: action,
        performedBy: performer.uid,
        performedByName: performer.displayName,
        fromDepartment: fromDepartment,
        toDepartment: toDepartment,
        notes: notes,
        timestamp: DateTime.now(),
      ),
    );
  }
}
