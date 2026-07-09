import 'dart:typed_data';

import '../core/helpers/picked_file.dart';
import '../models/app_user.dart';
import '../models/department_workflow_data.dart';
import '../models/enums/delivery_status.dart';
import '../models/enums/department.dart';
import '../models/order_history_entry.dart';
import '../models/enums/department_stage_status.dart';
import '../models/enums/history_action.dart';
import '../models/enums/inspection_status.dart';
import '../models/enums/order_status.dart';
import '../models/order_material.dart';
import '../models/production_order.dart';
import '../core/permissions/app_permission.dart';
import '../core/permissions/permission_context.dart';
import '../utils/exceptions/exceptions.dart';
import 'history_service.dart';
import 'permission_service.dart';
import 'production_order_repository.dart';
import 'storage_service.dart';

class WorkflowService {
  WorkflowService(
    this._orderRepository,
    this._historyService,
    this._storageService, [
    PermissionService permissions = const PermissionService(),
  ]) : _permissions = permissions;

  final ProductionOrderRepository _orderRepository;
  final HistoryService _historyService;
  final StorageService _storageService;
  final PermissionService _permissions;

  void _requireAction(
    AppUser performer,
    AppPermission permission,
    ProductionOrder order,
  ) {
    final context = PermissionContext(
      order: order,
      department: order.currentDepartment,
    );
    _permissions.requireOrderAccess(performer, context);
    _permissions.require(performer, permission, context: context);
  }

  Future<void> updateMaterials({
    required ProductionOrder order,
    required AppUser performer,
    required List<OrderMaterial> materials,
  }) async {
    _requireAction(performer, AppPermission.editOrders, order);
    if (materials.isEmpty) {
      throw const WorkflowException('At least one material is required');
    }

    await _orderRepository.updateOrder(
      order.copyWith(materials: materials, updatedAt: DateTime.now()),
    );
    await _log(
      order: order,
      action: HistoryAction.materialsUpdated,
      performer: performer,
      notes: 'Updated ${materials.length} material(s)',
    );
  }

  Future<String> uploadOrderDocument({
    required ProductionOrder order,
    required AppUser performer,
    required PickedFile file,
    required String documentType,
  }) async {
    _requireAction(performer, AppPermission.editOrders, order);
    final url = await _storageService.uploadOrderAttachment(
      orderId: order.id,
      fileName:
          '${documentType}_${DateTime.now().millisecondsSinceEpoch}_${file.fileName}',
      bytes: file.bytes,
      contentType: file.contentType,
    );

    final updated = documentType == 'pdf'
        ? order.copyWith(pdfUrl: url, updatedAt: DateTime.now())
        : order.copyWith(dxfUrl: url, updatedAt: DateTime.now());

    await _orderRepository.updateOrder(updated);
    await _log(
      order: order,
      action: HistoryAction.fileUploaded,
      performer: performer,
      notes: 'Uploaded $documentType file: ${file.fileName}',
    );
    return url;
  }

  Future<void> startWork({
    required ProductionOrder order,
    required AppUser performer,
  }) async {
    _requireAction(performer, AppPermission.startWork, order);
    _ensureOrderActive(order);

    final dept = order.currentDepartment;
    final workflow = order.workflowFor(dept);
    if (workflow.workStarted) {
      throw const WorkflowException('Work already started for this department');
    }

    final updatedWorkflow = Map<String, DepartmentWorkflowData>.from(
      order.workflowData,
    );
    updatedWorkflow[dept.name] = workflow.copyWith(
      workStarted: true,
      workStartedAt: DateTime.now(),
    );

    final statuses = Map<String, String>.from(order.departmentStatuses);
    statuses[dept.name] = DepartmentStageStatus.active.name;

    final updated = order.copyWith(
      departmentStatuses: statuses,
      workflowData: updatedWorkflow,
      status: OrderStatus.inProgress,
      startedAt: order.startedAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _orderRepository.updateOrder(updated);
    await _log(
      order: order,
      action: HistoryAction.workStarted,
      performer: performer,
      department: dept,
      notes: 'Work started in ${dept.label}',
    );
  }

  Future<void> pauseWork({
    required ProductionOrder order,
    required AppUser performer,
    String notes = '',
  }) async {
    _requireAction(performer, AppPermission.pauseWork, order);
    _ensureOrderActive(order);

    final dept = order.currentDepartment;
    final workflow = order.workflowFor(dept);
    if (!workflow.workStarted) {
      throw const WorkflowException('Start work before pausing');
    }
    if (workflow.paused) {
      throw const WorkflowException('Work is already paused');
    }

    final updatedWorkflow = Map<String, DepartmentWorkflowData>.from(
      order.workflowData,
    );
    updatedWorkflow[dept.name] = workflow.copyWith(paused: true);

    await _orderRepository.updateOrder(
      order.copyWith(workflowData: updatedWorkflow, updatedAt: DateTime.now()),
    );
    await _log(
      order: order,
      action: HistoryAction.workPaused,
      performer: performer,
      department: dept,
      notes: notes.isNotEmpty ? notes : 'Work paused in ${dept.label}',
    );
  }

  Future<void> resumeWork({
    required ProductionOrder order,
    required AppUser performer,
    String notes = '',
  }) async {
    _requireAction(performer, AppPermission.resumeWork, order);
    _ensureOrderActive(order);

    final dept = order.currentDepartment;
    final workflow = order.workflowFor(dept);
    if (!workflow.paused) {
      throw const WorkflowException('Work is not paused');
    }

    final updatedWorkflow = Map<String, DepartmentWorkflowData>.from(
      order.workflowData,
    );
    updatedWorkflow[dept.name] = workflow.copyWith(paused: false);

    await _orderRepository.updateOrder(
      order.copyWith(workflowData: updatedWorkflow, updatedAt: DateTime.now()),
    );
    await _log(
      order: order,
      action: HistoryAction.workResumed,
      performer: performer,
      department: dept,
      notes: notes.isNotEmpty ? notes : 'Work resumed in ${dept.label}',
    );
  }

  Future<void> addDepartmentNotes({
    required ProductionOrder order,
    required AppUser performer,
    required String notes,
  }) async {
    _requireAction(performer, AppPermission.addNotes, order);
    if (notes.trim().isEmpty) {
      throw const WorkflowException('Notes cannot be empty');
    }

    final dept = order.currentDepartment;
    final workflow = order.workflowFor(dept);
    final combinedNotes = workflow.notes.isEmpty
        ? notes.trim()
        : '${workflow.notes}\n${notes.trim()}';

    final updatedWorkflow = Map<String, DepartmentWorkflowData>.from(
      order.workflowData,
    );
    updatedWorkflow[dept.name] = workflow.copyWith(notes: combinedNotes);

    await _orderRepository.updateOrder(
      order.copyWith(
        workflowData: updatedWorkflow,
        notes: combinedNotes,
        updatedAt: DateTime.now(),
      ),
    );
    await _log(
      order: order,
      action: HistoryAction.noteAdded,
      performer: performer,
      department: dept,
      notes: notes.trim(),
    );
  }

  Future<void> saveProgress({
    required ProductionOrder order,
    required AppUser performer,
    required int inputQty,
    required int passQty,
    required int rejectQty,
    List<String> rejectReasons = const [],
  }) async {
    final dept = order.currentDepartment;
    final progressPermission = dept == Department.quality
        ? AppPermission.passRejectInspection
        : AppPermission.finishDepartment;
    _requireAction(performer, progressPermission, order);
    _ensureWorkInProgress(order);

    if (inputQty < 0 || passQty < 0 || rejectQty < 0) {
      throw const WorkflowException('Quantities cannot be negative');
    }
    if (rejectQty > 0 && rejectReasons.isEmpty) {
      throw const WorkflowException('Reject reasons are required when reject qty > 0');
    }

    if (dept == Department.assemblyAutoclave) {
      if (inputQty > 0 && passQty + rejectQty > inputQty) {
        throw const WorkflowException(
          'Pass + reject cannot exceed input quantity',
        );
      }
    } else if (passQty + rejectQty > inputQty) {
      throw const WorkflowException('Pass + reject cannot exceed input quantity');
    }

    final workflow = order.workflowFor(dept);
    final updatedWorkflow = Map<String, DepartmentWorkflowData>.from(
      order.workflowData,
    );
    updatedWorkflow[dept.name] = workflow.copyWith(
      inputQty: inputQty,
      passQty: passQty,
      rejectQty: rejectQty,
      rejectReasons: rejectReasons,
      progressSavedAt: DateTime.now(),
    );

    await _orderRepository.updateOrder(
      order.copyWith(workflowData: updatedWorkflow, updatedAt: DateTime.now()),
    );
    await _log(
      order: order,
      action: HistoryAction.progressSaved,
      performer: performer,
      department: dept,
      notes:
          'Input: $inputQty, Pass: $passQty, Reject: $rejectQty',
    );
  }

  Future<void> startInspection({
    required ProductionOrder order,
    required AppUser performer,
  }) async {
    if (order.currentDepartment != Department.assemblyAutoclave) {
      throw const WorkflowException(
        'Inspection can only be started in Assembly & Autoclave',
      );
    }
    _ensureWorkInProgress(order);

    if (order.inspectionStatus != InspectionStatus.notStarted &&
        order.inspectionStatus != InspectionStatus.pending) {
      throw const WorkflowException(
        'Inspection already in progress or completed',
      );
    }

    final updated = order.copyWith(
      inspectionStatus: InspectionStatus.pending,
      updatedAt: DateTime.now(),
    );

    await _orderRepository.updateOrder(updated);
    await _log(
      order: order,
      action: HistoryAction.inspectionStarted,
      performer: performer,
      department: order.currentDepartment,
      notes: 'Inspection initiated in Assembly & Autoclave',
    );
  }

  Future<void> completeInspection({
    required ProductionOrder order,
    required AppUser performer,
    required bool passed,
    String notes = '',
  }) async {
    if (order.currentDepartment != Department.assemblyAutoclave) {
      throw const WorkflowException(
        'Inspection can only be completed in Assembly & Autoclave',
      );
    }

    if (order.inspectionStatus != InspectionStatus.pending) {
      throw const WorkflowException('No pending inspection for this order');
    }

    final status = passed ? InspectionStatus.passed : InspectionStatus.failed;
    final updated = order.copyWith(
      inspectionStatus: status,
      notes: notes.isNotEmpty ? notes : order.notes,
      updatedAt: DateTime.now(),
    );

    await _orderRepository.updateOrder(updated);
    await _log(
      order: order,
      action: HistoryAction.inspectionCompleted,
      performer: performer,
      department: order.currentDepartment,
      toStatus: status.label,
      notes: notes.isNotEmpty
          ? notes
          : (passed ? 'Inspection passed' : 'Inspection failed'),
    );
  }

  Future<List<String>> uploadDepartmentPhotos({
    required ProductionOrder order,
    required AppUser performer,
    required List<({String fileName, Uint8List bytes, String contentType})> files,
    bool isFinalInspection = false,
  }) async {
    _requireAction(performer, AppPermission.addInspectionPhotos, order);
    if (files.isEmpty) {
      throw const WorkflowException('No photos selected');
    }

    final dept = order.currentDepartment;
    final workflow = order.workflowFor(dept);
    final urls = <String>[];

    for (final file in files) {
      final url = await _storageService.uploadOrderAttachment(
        orderId: order.id,
        fileName: '${dept.name}_${DateTime.now().millisecondsSinceEpoch}_${file.fileName}',
        bytes: file.bytes,
        contentType: file.contentType,
      );
      urls.add(url);
    }

    final updatedWorkflow = Map<String, DepartmentWorkflowData>.from(
      order.workflowData,
    );
    updatedWorkflow[dept.name] = workflow.copyWith(
      photoUrls: [...workflow.photoUrls, ...urls],
    );

    await _orderRepository.updateOrder(
      order.copyWith(workflowData: updatedWorkflow, updatedAt: DateTime.now()),
    );
    await _log(
      order: order,
      action: HistoryAction.photoUploaded,
      performer: performer,
      department: dept,
      notes: isFinalInspection
          ? 'Uploaded ${urls.length} final inspection photo(s)'
          : 'Uploaded ${urls.length} inspection photo(s)',
    );
    return urls;
  }

  Future<void> approveQuality({
    required ProductionOrder order,
    required AppUser performer,
    required String digitalSignature,
  }) async {
    if (order.currentDepartment != Department.quality) {
      throw const WorkflowException('Quality approval is only for Quality department');
    }
    _requireAction(performer, AppPermission.signInspection, order);
    if (digitalSignature.trim().isEmpty) {
      throw const WorkflowException('Digital signature is required');
    }

    final workflow = order.workflowFor(Department.quality);
    if (workflow.passQty <= 0 && workflow.rejectQty <= 0) {
      throw const WorkflowException('Save inspection quantities before approval');
    }

    final updatedWorkflow = Map<String, DepartmentWorkflowData>.from(
      order.workflowData,
    );
    updatedWorkflow[Department.quality.name] = workflow.copyWith(
      digitalSignature: digitalSignature.trim(),
      approvedBy: performer.displayName,
      approvedAt: DateTime.now(),
    );

    await _orderRepository.updateOrder(
      order.copyWith(workflowData: updatedWorkflow, updatedAt: DateTime.now()),
    );
    await _log(
      order: order,
      action: HistoryAction.qualityApproved,
      performer: performer,
      department: Department.quality,
      notes: 'Signed by ${digitalSignature.trim()}',
    );
  }

  Future<void> finishDepartment({
    required ProductionOrder order,
    required AppUser performer,
    String notes = '',
  }) async {
    await transferToNextDepartment(
      order: order,
      performer: performer,
      notes: notes,
    );
  }

  Future<void> transferToNextDepartment({
    required ProductionOrder order,
    required AppUser performer,
    String notes = '',
  }) async {
    _requireAction(performer, AppPermission.transferOrders, order);
    _ensureOrderActive(order);
    _ensureWorkInProgress(order);

    final dept = order.currentDepartment;
    await _validateDepartmentTransferRequirements(order, dept);

    var currentOrder = order;
    if (dept == Department.assemblyAutoclave) {
      await _createReworkOrdersIfNeeded(currentOrder, performer);
      currentOrder = await _orderRepository.getOrder(order.id) ?? order;
    }

    final statuses = Map<String, String>.from(currentOrder.departmentStatuses);
    statuses[dept.name] = DepartmentStageStatus.completed.name;

    final workflow = currentOrder.workflowFor(dept);
    final updatedWorkflow = Map<String, DepartmentWorkflowData>.from(
      currentOrder.workflowData,
    );
    updatedWorkflow[dept.name] = workflow.copyWith(finishedAt: DateTime.now());

    final nextDepartment = dept.next;
    if (nextDepartment == null) {
      throw const WorkflowException('No next department to transfer to');
    }

    statuses[nextDepartment.name] = DepartmentStageStatus.active.name;

    var updated = currentOrder.copyWith(
      currentDepartment: nextDepartment,
      departmentStatuses: statuses,
      workflowData: updatedWorkflow,
      inspectionStatus: nextDepartment == Department.assemblyAutoclave
          ? currentOrder.inspectionStatus
          : InspectionStatus.notStarted,
      clearAssignedOperator: true,
      updatedAt: DateTime.now(),
    );

    if (nextDepartment == Department.finishedDelivery) {
      final finishedWorkflow = updated.workflowFor(Department.finishedDelivery)
          .copyWith(deliveryStatus: DeliveryStatus.ready);
      updatedWorkflow[Department.finishedDelivery.name] = finishedWorkflow;
      updated = updated.copyWith(workflowData: updatedWorkflow);
    }

    await _orderRepository.updateOrder(updated);
    await _log(
      order: order,
      action: HistoryAction.transferred,
      performer: performer,
      department: dept,
      toDepartment: nextDepartment,
      notes: notes.isNotEmpty ? notes : 'Transferred to ${nextDepartment.label}',
    );
  }

  Future<void> completeDepartmentStage({
    required ProductionOrder order,
    required AppUser performer,
    String notes = '',
  }) async {
    await transferToNextDepartment(
      order: order,
      performer: performer,
      notes: notes,
    );
  }

  Future<void> finishOrder({
    required ProductionOrder order,
    required AppUser performer,
    String notes = '',
  }) async {
    if (order.currentDepartment != Department.finishedDelivery) {
      throw const WorkflowException(
        'Order can only be finished in Finished & Delivery',
      );
    }
    _requireAction(performer, AppPermission.finishOrders, order);

    final workflow = order.workflowFor(Department.finishedDelivery);
    if (!workflow.customerConfirmed) {
      throw const WorkflowException(
        'Customer delivery confirmation is required before finishing',
      );
    }

    final statuses = Map<String, String>.from(order.departmentStatuses);
    statuses[Department.finishedDelivery.name] =
        DepartmentStageStatus.completed.name;

    final updatedWorkflow = Map<String, DepartmentWorkflowData>.from(
      order.workflowData,
    );
    updatedWorkflow[Department.finishedDelivery.name] = workflow.copyWith(
      finishedAt: DateTime.now(),
      deliveryStatus: DeliveryStatus.confirmed,
    );

    final updated = order.copyWith(
      status: OrderStatus.completed,
      departmentStatuses: statuses,
      workflowData: updatedWorkflow,
      completedAt: DateTime.now(),
      clearAssignedOperator: true,
      updatedAt: DateTime.now(),
    );

    await _orderRepository.updateOrder(updated);
    await _log(
      order: order,
      action: HistoryAction.completed,
      performer: performer,
      department: Department.finishedDelivery,
      notes: notes.isNotEmpty ? notes : 'Production order completed',
    );
  }

  Future<void> recordLabelPrinted({
    required ProductionOrder order,
    required AppUser performer,
  }) async {
    if (order.currentDepartment != Department.finishedDelivery) {
      throw const WorkflowException('Labels can only be printed in Finished & Delivery');
    }
    _requireAction(performer, AppPermission.printLabels, order);

    final workflow = order.workflowFor(Department.finishedDelivery);
    final updatedWorkflow = Map<String, DepartmentWorkflowData>.from(
      order.workflowData,
    );
    updatedWorkflow[Department.finishedDelivery.name] = workflow.copyWith(
      labelPrintedAt: DateTime.now(),
    );

    await _orderRepository.updateOrder(
      order.copyWith(workflowData: updatedWorkflow, updatedAt: DateTime.now()),
    );
    await _log(
      order: order,
      action: HistoryAction.labelPrinted,
      performer: performer,
      department: Department.finishedDelivery,
      notes: 'Shipping label printed for ${order.orderNumber}',
    );
  }

  Future<void> updateDeliveryStatus({
    required ProductionOrder order,
    required AppUser performer,
    required DeliveryStatus status,
    String notes = '',
  }) async {
    if (order.currentDepartment != Department.finishedDelivery) {
      throw const WorkflowException(
        'Delivery status can only be updated in Finished & Delivery',
      );
    }
    _requireAction(performer, AppPermission.updateDeliveryStatus, order);

    final workflow = order.workflowFor(Department.finishedDelivery);
    final updatedWorkflow = Map<String, DepartmentWorkflowData>.from(
      order.workflowData,
    );
    updatedWorkflow[Department.finishedDelivery.name] = workflow.copyWith(
      deliveryStatus: status,
    );

    await _orderRepository.updateOrder(
      order.copyWith(workflowData: updatedWorkflow, updatedAt: DateTime.now()),
    );
    await _log(
      order: order,
      action: HistoryAction.deliveryUpdated,
      performer: performer,
      department: Department.finishedDelivery,
      toStatus: status.label,
      notes: notes,
    );
  }

  Future<void> confirmCustomerDelivery({
    required ProductionOrder order,
    required AppUser performer,
    String notes = '',
  }) async {
    if (order.currentDepartment != Department.finishedDelivery) {
      throw const WorkflowException(
        'Customer confirmation is only for Finished & Delivery',
      );
    }
    _requireAction(performer, AppPermission.customerDeliveryConfirmation, order);

    final workflow = order.workflowFor(Department.finishedDelivery);
    final updatedWorkflow = Map<String, DepartmentWorkflowData>.from(
      order.workflowData,
    );
    updatedWorkflow[Department.finishedDelivery.name] = workflow.copyWith(
      customerConfirmed: true,
      customerConfirmedAt: DateTime.now(),
      deliveryStatus: DeliveryStatus.delivered,
    );

    await _orderRepository.updateOrder(
      order.copyWith(workflowData: updatedWorkflow, updatedAt: DateTime.now()),
    );
    await _log(
      order: order,
      action: HistoryAction.customerConfirmed,
      performer: performer,
      department: Department.finishedDelivery,
      notes: notes.isNotEmpty ? notes : 'Customer confirmed delivery',
    );
  }

  Future<void> assignOperator({
    required ProductionOrder order,
    required AppUser operator,
    required AppUser performer,
  }) async {
    if (!operator.isActive) {
      throw const WorkflowException('Selected operator is inactive');
    }
    _requireAction(performer, AppPermission.reviewOperators, order);

    final updated = order.copyWith(
      assignedOperatorId: operator.uid,
      assignedOperatorName: operator.displayName,
      updatedAt: DateTime.now(),
    );

    await _orderRepository.updateOrder(updated);
    await _log(
      order: order,
      action: HistoryAction.assigned,
      performer: performer,
      notes: 'Assigned to ${operator.displayName}',
    );
  }

  Future<void> unassignOperator({
    required ProductionOrder order,
    required AppUser performer,
  }) async {
    _requireAction(performer, AppPermission.reviewOperators, order);
    final updated = order.copyWith(
      clearAssignedOperator: true,
      updatedAt: DateTime.now(),
    );

    await _orderRepository.updateOrder(updated);
    await _log(
      order: order,
      action: HistoryAction.unassigned,
      performer: performer,
    );
  }

  Future<void> setOnHold({
    required ProductionOrder order,
    required AppUser performer,
    required String reason,
  }) async {
    if (order.status == OrderStatus.completed ||
        order.status == OrderStatus.cancelled) {
      throw const WorkflowException('Cannot place a finished order on hold');
    }
    _permissions.require(performer, AppPermission.stopResumeOrders);

    final updated = order.copyWith(
      status: OrderStatus.onHold,
      notes: reason,
      updatedAt: DateTime.now(),
    );

    await _orderRepository.updateOrder(updated);
    await _log(
      order: order,
      action: HistoryAction.onHold,
      performer: performer,
      fromStatus: order.status.label,
      toStatus: OrderStatus.onHold.label,
      notes: reason,
    );
  }

  Future<void> resumeProduction({
    required ProductionOrder order,
    required AppUser performer,
  }) async {
    if (order.status != OrderStatus.onHold) {
      throw const WorkflowException('Order is not on hold');
    }
    _permissions.require(performer, AppPermission.stopResumeOrders);

    final updated = order.copyWith(
      status: OrderStatus.inProgress,
      updatedAt: DateTime.now(),
    );

    await _orderRepository.updateOrder(updated);
    await _log(
      order: order,
      action: HistoryAction.resumed,
      performer: performer,
      fromStatus: OrderStatus.onHold.label,
      toStatus: OrderStatus.inProgress.label,
    );
  }

  Future<void> cancelOrder({
    required ProductionOrder order,
    required AppUser performer,
    required String reason,
  }) async {
    if (order.status == OrderStatus.completed) {
      throw const WorkflowException('Cannot cancel a completed order');
    }

    final updated = order.copyWith(
      status: OrderStatus.cancelled,
      notes: reason,
      clearAssignedOperator: true,
      updatedAt: DateTime.now(),
    );

    await _orderRepository.updateOrder(updated);
    await _log(
      order: order,
      action: HistoryAction.cancelled,
      performer: performer,
      notes: reason,
    );
  }

  Future<void> _createReworkOrdersIfNeeded(
    ProductionOrder order,
    AppUser performer,
  ) async {
    final workflow = order.workflowFor(Department.assemblyAutoclave);
    if (workflow.rejectQty <= 0) return;

    final reworkOrder = await _orderRepository.createReworkOrder(
      parentOrder: order,
      quantity: workflow.rejectQty,
      rejectReasons: workflow.rejectReasons,
      createdBy: performer.uid,
    );

    final reworkIds = [...order.reworkOrderIds, reworkOrder.id];
    await _orderRepository.updateOrder(
      order.copyWith(reworkOrderIds: reworkIds, updatedAt: DateTime.now()),
    );

    await _historyService.logEntry(
      OrderHistoryEntry(
        id: '',
        orderId: order.id,
        action: HistoryAction.reworkCreated,
        performedBy: performer.uid,
        performedByName: performer.displayName,
        fromDepartment: Department.assemblyAutoclave,
        notes:
            'Created rework order ${reworkOrder.orderNumber} for ${workflow.rejectQty} unit(s)',
        timestamp: DateTime.now(),
      ),
    );

    await _historyService.logEntry(
      OrderHistoryEntry(
        id: '',
        orderId: reworkOrder.id,
        action: HistoryAction.created,
        performedBy: performer.uid,
        performedByName: performer.displayName,
        notes: 'Rework order created from ${order.orderNumber}',
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _validateDepartmentTransferRequirements(
    ProductionOrder order,
    Department dept,
  ) async {
    final workflow = order.workflowFor(dept);

    switch (dept) {
      case Department.glassProcessing:
      case Department.grindingWashing:
        return;
      case Department.assemblyAutoclave:
        return;
      case Department.quality:
        if (workflow.passQty <= 0 && workflow.rejectQty <= 0) {
          throw const WorkflowException(
            'Save final inspection quantities before transferring',
          );
        }
        if (workflow.approvedAt == null || workflow.digitalSignature.isEmpty) {
          throw const WorkflowException(
            'Quality approval and digital signature required',
          );
        }
        return;
      case Department.finishedDelivery:
        throw const WorkflowException(
          'Use Finish Order in Finished & Delivery department',
        );
    }
  }

  void _ensureOrderActive(ProductionOrder order) {
    if (order.status == OrderStatus.onHold) {
      throw const WorkflowException(
        'Order is on hold. Resume production before continuing.',
      );
    }
    if (order.status == OrderStatus.completed ||
        order.status == OrderStatus.cancelled) {
      throw const WorkflowException('Order is no longer active');
    }
  }

  void _ensureWorkInProgress(ProductionOrder order) {
    _ensureOrderActive(order);
    final workflow = order.workflowFor(order.currentDepartment);
    if (!workflow.workStarted) {
      throw const WorkflowException('Start work before performing this action');
    }
    if (workflow.paused) {
      throw const WorkflowException('Resume work before performing this action');
    }
  }

  Future<void> _log({
    required ProductionOrder order,
    required HistoryAction action,
    required AppUser performer,
    Department? department,
    Department? toDepartment,
    String? fromStatus,
    String? toStatus,
    String notes = '',
  }) async {
    await _historyService.logEntry(
      OrderHistoryEntry(
        id: '',
        orderId: order.id,
        action: action,
        performedBy: performer.uid,
        performedByName: performer.displayName,
        fromDepartment: department ?? order.currentDepartment,
        toDepartment: toDepartment,
        fromStatus: fromStatus,
        toStatus: toStatus,
        notes: notes,
        timestamp: DateTime.now(),
      ),
    );
  }
}
