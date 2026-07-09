import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/helpers/parse_helpers.dart';
import 'enums/delivery_status.dart';

class DepartmentWorkflowData {
  const DepartmentWorkflowData({
    this.workStarted = false,
    this.paused = false,
    this.notes = '',
    this.inputQty = 0,
    this.passQty = 0,
    this.rejectQty = 0,
    this.rejectReasons = const [],
    this.photoUrls = const [],
    this.workStartedAt,
    this.finishedAt,
    this.progressSavedAt,
    this.digitalSignature = '',
    this.approvedBy = '',
    this.approvedAt,
    this.deliveryStatus = DeliveryStatus.pending,
    this.customerConfirmed = false,
    this.customerConfirmedAt,
    this.labelPrintedAt,
  });

  final bool workStarted;
  final bool paused;
  final String notes;
  final int inputQty;
  final int passQty;
  final int rejectQty;
  final List<String> rejectReasons;
  final List<String> photoUrls;
  final DateTime? workStartedAt;
  final DateTime? finishedAt;
  final DateTime? progressSavedAt;
  final String digitalSignature;
  final String approvedBy;
  final DateTime? approvedAt;
  final DeliveryStatus deliveryStatus;
  final bool customerConfirmed;
  final DateTime? customerConfirmedAt;
  final DateTime? labelPrintedAt;

  DepartmentWorkflowData copyWith({
    bool? workStarted,
    bool? paused,
    String? notes,
    int? inputQty,
    int? passQty,
    int? rejectQty,
    List<String>? rejectReasons,
    List<String>? photoUrls,
    DateTime? workStartedAt,
    DateTime? finishedAt,
    DateTime? progressSavedAt,
    String? digitalSignature,
    String? approvedBy,
    DateTime? approvedAt,
    DeliveryStatus? deliveryStatus,
    bool? customerConfirmed,
    DateTime? customerConfirmedAt,
    DateTime? labelPrintedAt,
  }) {
    return DepartmentWorkflowData(
      workStarted: workStarted ?? this.workStarted,
      paused: paused ?? this.paused,
      notes: notes ?? this.notes,
      inputQty: inputQty ?? this.inputQty,
      passQty: passQty ?? this.passQty,
      rejectQty: rejectQty ?? this.rejectQty,
      rejectReasons: rejectReasons ?? this.rejectReasons,
      photoUrls: photoUrls ?? this.photoUrls,
      workStartedAt: workStartedAt ?? this.workStartedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      progressSavedAt: progressSavedAt ?? this.progressSavedAt,
      digitalSignature: digitalSignature ?? this.digitalSignature,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      customerConfirmed: customerConfirmed ?? this.customerConfirmed,
      customerConfirmedAt: customerConfirmedAt ?? this.customerConfirmedAt,
      labelPrintedAt: labelPrintedAt ?? this.labelPrintedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workStarted': workStarted,
      'paused': paused,
      'notes': notes,
      'inputQty': inputQty,
      'passQty': passQty,
      'rejectQty': rejectQty,
      'rejectReasons': rejectReasons,
      'photoUrls': photoUrls,
      'workStartedAt':
          workStartedAt != null ? Timestamp.fromDate(workStartedAt!) : null,
      'finishedAt':
          finishedAt != null ? Timestamp.fromDate(finishedAt!) : null,
      'progressSavedAt': progressSavedAt != null
          ? Timestamp.fromDate(progressSavedAt!)
          : null,
      'digitalSignature': digitalSignature,
      'approvedBy': approvedBy,
      'approvedAt':
          approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'deliveryStatus': deliveryStatus.name,
      'customerConfirmed': customerConfirmed,
      'customerConfirmedAt': customerConfirmedAt != null
          ? Timestamp.fromDate(customerConfirmedAt!)
          : null,
      'labelPrintedAt':
          labelPrintedAt != null ? Timestamp.fromDate(labelPrintedAt!) : null,
    };
  }

  factory DepartmentWorkflowData.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const DepartmentWorkflowData();
    final reasons = map['rejectReasons'];
    final photos = map['photoUrls'];
    return DepartmentWorkflowData(
      workStarted: map['workStarted'] as bool? ?? false,
      paused: map['paused'] as bool? ?? false,
      notes: map['notes'] as String? ?? '',
      inputQty: ParseHelpers.parseInt(map['inputQty']),
      passQty: ParseHelpers.parseInt(map['passQty']),
      rejectQty: ParseHelpers.parseInt(map['rejectQty']),
      rejectReasons: reasons is List
          ? reasons.map((e) => e.toString()).toList()
          : const [],
      photoUrls:
          photos is List ? photos.map((e) => e.toString()).toList() : const [],
      workStartedAt: _parseTimestamp(map['workStartedAt']),
      finishedAt: _parseTimestamp(map['finishedAt']),
      progressSavedAt: _parseTimestamp(map['progressSavedAt']),
      digitalSignature: map['digitalSignature'] as String? ?? '',
      approvedBy: map['approvedBy'] as String? ?? '',
      approvedAt: _parseTimestamp(map['approvedAt']),
      deliveryStatus: DeliveryStatus.fromString(
        map['deliveryStatus'] as String? ?? 'pending',
      ),
      customerConfirmed: map['customerConfirmed'] as bool? ?? false,
      customerConfirmedAt: _parseTimestamp(map['customerConfirmedAt']),
      labelPrintedAt: _parseTimestamp(map['labelPrintedAt']),
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
