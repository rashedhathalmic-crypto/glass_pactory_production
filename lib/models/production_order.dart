import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/helpers/parse_helpers.dart';
import 'department_workflow_data.dart';
import 'enums/department.dart';
import 'enums/department_stage_status.dart';
import 'enums/inspection_status.dart';
import 'enums/order_priority.dart';
import 'enums/order_status.dart';
import 'enums/order_type.dart';
import 'order_material.dart';

class ProductionOrder {
  const ProductionOrder({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.glassType,
    required this.drawingNumber,
    required this.thicknessMm,
    required this.quantity,
    required this.status,
    required this.currentDepartment,
    required this.departmentStatuses,
    this.polygonSides = 4,
    this.polygonSideLengthsMm = const [],
    this.areaSqM = 0,
    this.pdfUrl = '',
    this.dxfUrl = '',
    this.materials = const [],
    this.description = '',
    this.projectName = '',
    this.priority = OrderPriority.normal,
    this.inspectionStatus = InspectionStatus.notStarted,
    this.assignedOperatorId,
    this.assignedOperatorName,
    this.notes = '',
    this.dueDate,
    this.startedAt,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.workflowData = const {},
    this.orderType = OrderType.standard,
    this.parentOrderId,
    this.reworkOrderIds = const [],
    this.isStopped = false,
    this.stopReason = '',
  });

  final String id;
  final String orderNumber;
  final String customerName;
  final String glassType;
  final String drawingNumber;
  final double thicknessMm;
  final int quantity;
  final int polygonSides;
  final List<double> polygonSideLengthsMm;
  final double areaSqM;
  final String pdfUrl;
  final String dxfUrl;
  final List<OrderMaterial> materials;
  final OrderStatus status;
  final OrderPriority priority;
  final Department currentDepartment;
  final Map<String, String> departmentStatuses;
  final InspectionStatus inspectionStatus;
  final String description;
  final String projectName;
  final String? assignedOperatorId;
  final String? assignedOperatorName;
  final String notes;
  final DateTime? dueDate;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final Map<String, DepartmentWorkflowData> workflowData;
  final OrderType orderType;
  final String? parentOrderId;
  final List<String> reworkOrderIds;
  final bool isStopped;
  final String stopReason;

  String get dimensionsLabel =>
      '$drawingNumber · ${areaSqM.toStringAsFixed(2)} m² · ${thicknessMm.toStringAsFixed(1)} mm';

  DepartmentStageStatus stageStatusFor(Department department) {
    final value = departmentStatuses[department.name];
    if (value == null) return DepartmentStageStatus.pending;
    return DepartmentStageStatus.fromString(value);
  }

  bool get isInspectionApplicable =>
      currentDepartment == Department.assemblyAutoclave ||
      inspectionStatus != InspectionStatus.notStarted;

  DepartmentWorkflowData workflowFor(Department department) {
    return workflowData[department.name] ?? const DepartmentWorkflowData();
  }

  ProductionOrder copyWith({
    String? id,
    String? orderNumber,
    String? customerName,
    String? glassType,
    String? drawingNumber,
    double? thicknessMm,
    int? quantity,
    int? polygonSides,
    List<double>? polygonSideLengthsMm,
    double? areaSqM,
    String? pdfUrl,
    String? dxfUrl,
    List<OrderMaterial>? materials,
    OrderStatus? status,
    OrderPriority? priority,
    Department? currentDepartment,
    Map<String, String>? departmentStatuses,
    InspectionStatus? inspectionStatus,
    String? description,
    String? projectName,
    String? assignedOperatorId,
    String? assignedOperatorName,
    String? notes,
    DateTime? dueDate,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    Map<String, DepartmentWorkflowData>? workflowData,
    OrderType? orderType,
    String? parentOrderId,
    List<String>? reworkOrderIds,
    bool? isStopped,
    String? stopReason,
    bool clearAssignedOperator = false,
  }) {
    return ProductionOrder(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerName: customerName ?? this.customerName,
      glassType: glassType ?? this.glassType,
      drawingNumber: drawingNumber ?? this.drawingNumber,
      thicknessMm: thicknessMm ?? this.thicknessMm,
      quantity: quantity ?? this.quantity,
      polygonSides: polygonSides ?? this.polygonSides,
      polygonSideLengthsMm:
          polygonSideLengthsMm ?? this.polygonSideLengthsMm,
      areaSqM: areaSqM ?? this.areaSqM,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      dxfUrl: dxfUrl ?? this.dxfUrl,
      materials: materials ?? this.materials,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      currentDepartment: currentDepartment ?? this.currentDepartment,
      departmentStatuses: departmentStatuses ?? this.departmentStatuses,
      inspectionStatus: inspectionStatus ?? this.inspectionStatus,
      description: description ?? this.description,
      projectName: projectName ?? this.projectName,
      assignedOperatorId: clearAssignedOperator
          ? null
          : (assignedOperatorId ?? this.assignedOperatorId),
      assignedOperatorName: clearAssignedOperator
          ? null
          : (assignedOperatorName ?? this.assignedOperatorName),
      notes: notes ?? this.notes,
      dueDate: dueDate ?? this.dueDate,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      workflowData: workflowData ?? this.workflowData,
      orderType: orderType ?? this.orderType,
      parentOrderId: parentOrderId ?? this.parentOrderId,
      reworkOrderIds: reworkOrderIds ?? this.reworkOrderIds,
      isStopped: isStopped ?? this.isStopped,
      stopReason: stopReason ?? this.stopReason,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderNumber': orderNumber,
      'customerName': customerName,
      'glassType': glassType,
      'drawingNumber': drawingNumber,
      'thicknessMm': thicknessMm,
      'quantity': quantity,
      'polygonSides': polygonSides,
      'polygonSideLengthsMm': polygonSideLengthsMm,
      'areaSqM': areaSqM,
      'pdfUrl': pdfUrl,
      'dxfUrl': dxfUrl,
      'materials': materials.map((m) => m.toMap()).toList(),
      'status': status.name,
      'priority': priority.name,
      'currentDepartment': currentDepartment.name,
      'departmentStatuses': departmentStatuses,
      'inspectionStatus': inspectionStatus.name,
      'description': description,
      'projectName': projectName,
      'assignedOperatorId': assignedOperatorId,
      'assignedOperatorName': assignedOperatorName,
      'notes': notes,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
      'workflowData': workflowData.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'orderType': orderType.name,
      'parentOrderId': parentOrderId,
      'reworkOrderIds': reworkOrderIds,
      'isStopped': isStopped,
      'stopReason': stopReason,
    };
  }

  factory ProductionOrder.fromMap(String id, Map<String, dynamic> map) {
    final rawStatuses = _asStringMap(map['departmentStatuses']);
    final rawWorkflow = _asStringMap(map['workflowData']);
    final rawReworkIds = map['reworkOrderIds'];
    final rawMaterials = map['materials'];
    final rawSideLengths = map['polygonSideLengthsMm'];
    return ProductionOrder(
      id: id,
      orderNumber: map['orderNumber'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      glassType: map['glassType'] as String? ?? '',
      drawingNumber: map['drawingNumber'] as String? ??
          map['partNumber'] as String? ??
          '',
      thicknessMm: ParseHelpers.parseDouble(map['thicknessMm']),
      quantity: ParseHelpers.parseInt(map['quantity']),
      polygonSides: ParseHelpers.parseInt(map['polygonSides'], fallback: 4),
      polygonSideLengthsMm: rawSideLengths is List
          ? ParseHelpers.parseDoubleList(rawSideLengths)
          : _legacySideLengths(map),
      areaSqM: _parseAreaSqM(map),
      pdfUrl: map['pdfUrl'] as String? ?? '',
      dxfUrl: map['dxfUrl'] as String? ?? '',
      materials: rawMaterials is List
          ? rawMaterials
              .whereType<Map<String, dynamic>>()
              .map(OrderMaterial.fromMap)
              .toList()
          : const [],
      status: OrderStatus.fromString(map['status'] as String? ?? 'draft'),
      priority: OrderPriority.fromString(
        map['priority'] as String? ?? 'normal',
      ),
      currentDepartment: Department.fromString(
        map['currentDepartment'] as String? ?? Department.glassProcessing.name,
      ),
      departmentStatuses: _normalizeDepartmentStatuses(rawStatuses),
      inspectionStatus: InspectionStatus.fromString(
        map['inspectionStatus'] as String? ?? 'notStarted',
      ),
      description: map['description'] as String? ?? '',
      projectName: map['projectName'] as String? ?? '',
      assignedOperatorId: map['assignedOperatorId'] as String?,
      assignedOperatorName: map['assignedOperatorName'] as String?,
      notes: map['notes'] as String? ?? '',
      dueDate: _parseTimestamp(map['dueDate']),
      startedAt: _parseTimestamp(map['startedAt']),
      completedAt: _parseTimestamp(map['completedAt']),
      createdAt: _parseTimestamp(map['createdAt']),
      updatedAt: _parseTimestamp(map['updatedAt']),
      createdBy: map['createdBy'] as String?,
      workflowData: _normalizeWorkflowData(rawWorkflow),
      orderType: OrderType.fromString(
        map['orderType'] as String? ?? 'standard',
      ),
      parentOrderId: map['parentOrderId'] as String?,
      reworkOrderIds: rawReworkIds is List
          ? rawReworkIds.map((e) => e.toString()).toList()
          : const [],
      isStopped: map['isStopped'] as bool? ?? false,
      stopReason: map['stopReason'] as String? ?? '',
    );
  }

  factory ProductionOrder.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ProductionOrder.fromMap(doc.id, doc.data() ?? {});
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static Map<String, String> _normalizeDepartmentStatuses(
    Map<String, dynamic>? raw,
  ) {
    if (raw == null) return {};
    final result = <String, String>{};
    for (final entry in raw.entries) {
      final key = Department.normalizeStorageKey(entry.key.toString());
      result[key] = entry.value.toString();
    }
    return result;
  }

  static Map<String, DepartmentWorkflowData> _normalizeWorkflowData(
    Map<String, dynamic>? raw,
  ) {
    if (raw == null) return {};
    final result = <String, DepartmentWorkflowData>{};
    for (final entry in raw.entries) {
      final key = Department.normalizeStorageKey(entry.key.toString());
      final value = entry.value;
      final existing = result[key];
      final parsed = DepartmentWorkflowData.fromMap(
        value is Map<String, dynamic> ? value : null,
      );
      result[key] = existing == null
          ? parsed
          : _mergeWorkflowData(existing, parsed);
    }
    return result;
  }

  static DepartmentWorkflowData _mergeWorkflowData(
    DepartmentWorkflowData primary,
    DepartmentWorkflowData secondary,
  ) {
    return primary.copyWith(
      workStarted: primary.workStarted || secondary.workStarted,
      paused: primary.paused || secondary.paused,
      notes: primary.notes.isNotEmpty ? primary.notes : secondary.notes,
      inputQty: primary.inputQty > 0 ? primary.inputQty : secondary.inputQty,
      passQty: primary.passQty > 0 ? primary.passQty : secondary.passQty,
      rejectQty: primary.rejectQty > 0 ? primary.rejectQty : secondary.rejectQty,
      workStartedAt: primary.workStartedAt ?? secondary.workStartedAt,
      finishedAt: primary.finishedAt ?? secondary.finishedAt,
    );
  }

  static Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  static double _parseAreaSqM(Map<String, dynamic> map) {
    final parsed = ParseHelpers.parseDouble(map['areaSqM']);
    if (parsed > 0) return parsed;
    return _legacyAreaSqM(map);
  }

  static List<double> _legacySideLengths(Map<String, dynamic> map) {
    final width = ParseHelpers.parseDouble(map['widthMm']);
    final height = ParseHelpers.parseDouble(map['heightMm']);
    if (width > 0 && height > 0) {
      return [width, height, width, height];
    }
    return const [];
  }

  static double _legacyAreaSqM(Map<String, dynamic> map) {
    final width = ParseHelpers.parseDouble(map['widthMm']);
    final height = ParseHelpers.parseDouble(map['heightMm']);
    if (width > 0 && height > 0) {
      return (width * height) / 1000000;
    }
    return 0;
  }

  /// Returns Firestore patch to normalize legacy string numeric fields.
  Map<String, dynamic> legacyMigrationPatch(Map<String, dynamic> raw) {
    final patch = <String, dynamic>{
      'thicknessMm': thicknessMm,
      'quantity': quantity,
      'polygonSides': polygonSides,
      'polygonSideLengthsMm': polygonSideLengthsMm,
      'areaSqM': areaSqM,
      'drawingNumber': drawingNumber.isNotEmpty
          ? drawingNumber
          : (raw['partNumber'] as String? ?? ''),
      'widthMm': FieldValue.delete(),
      'heightMm': FieldValue.delete(),
      'partNumber': FieldValue.delete(),
    };

    final rawDepartment = raw['currentDepartment'] as String?;
    if (rawDepartment != null && rawDepartment != currentDepartment.name) {
      patch['currentDepartment'] = currentDepartment.name;
    }

    final rawStatuses = _asStringMap(raw['departmentStatuses']);
    if (rawStatuses != null) {
      final normalizedStatuses = _normalizeDepartmentStatuses(rawStatuses);
      final rawStatusStrings = {
        for (final entry in rawStatuses.entries)
          entry.key: entry.value.toString(),
      };
      if (!_stringMapsEqual(rawStatusStrings, normalizedStatuses)) {
        patch['departmentStatuses'] = normalizedStatuses;
      }
    }

    final legacyWorkflow = raw['workflowData'];
    if (legacyWorkflow is Map) {
      final normalizedWorkflow = <String, dynamic>{};
      legacyWorkflow.forEach((key, value) {
        if (value is Map) {
          final deptMap = Map<String, dynamic>.from(value);
          for (final qtyKey in ['inputQty', 'passQty', 'rejectQty']) {
            if (deptMap[qtyKey] is String) {
              deptMap[qtyKey] = ParseHelpers.parseInt(deptMap[qtyKey]);
            }
          }
          normalizedWorkflow[
              Department.normalizeStorageKey(key.toString())] = deptMap;
        }
      });
      if (normalizedWorkflow.isNotEmpty) {
        patch['workflowData'] = normalizedWorkflow;
      }
    }

    if (materials.isNotEmpty) {
      patch['materials'] = materials.map((m) => m.toMap()).toList();
    }

    return patch;
  }

  static bool _stringMapsEqual(
    Map<String, String> left,
    Map<String, String> right,
  ) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) return false;
    }
    return true;
  }

  bool needsLegacyMigration(Map<String, dynamic> raw) {
    final rawDepartment = raw['currentDepartment'] as String?;
    if (rawDepartment != null && rawDepartment != currentDepartment.name) {
      return true;
    }

    if (raw['widthMm'] != null ||
        raw['heightMm'] != null ||
        raw['partNumber'] != null ||
        raw['thicknessMm'] is String ||
        raw['quantity'] is String ||
        raw['areaSqM'] is String) {
      return true;
    }

    if (raw['polygonSideLengthsMm'] is List &&
        (raw['polygonSideLengthsMm'] as List).any((e) => e is String)) {
      return true;
    }

    final rawWorkflow = raw['workflowData'];
    if (rawWorkflow is Map) {
      for (final value in rawWorkflow.values) {
        if (value is Map) {
          for (final qtyKey in ['inputQty', 'passQty', 'rejectQty']) {
            if (value[qtyKey] is String) return true;
          }
        }
      }
    }

    final rawMaterials = raw['materials'];
    if (rawMaterials is List) {
      for (final item in rawMaterials) {
        if (item is Map && item['quantity'] is String) return true;
      }
    }

    return false;
  }

  static Map<String, String> initialDepartmentStatuses() {
    return {for (final dept in Department.values) dept.name: 'pending'};
  }

  static Map<String, DepartmentWorkflowData> initialWorkflowData() {
    return {
      for (final dept in Department.values)
        dept.name: const DepartmentWorkflowData(),
    };
  }
}
