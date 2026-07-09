import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums/department.dart';
import 'enums/history_action.dart';

class OrderHistoryEntry {
  const OrderHistoryEntry({
    required this.id,
    required this.orderId,
    required this.action,
    required this.performedBy,
    required this.performedByName,
    this.fromDepartment,
    this.toDepartment,
    this.fromStatus,
    this.toStatus,
    this.notes = '',
    this.timestamp,
  });

  final String id;
  final String orderId;
  final HistoryAction action;
  final String performedBy;
  final String performedByName;
  final Department? fromDepartment;
  final Department? toDepartment;
  final String? fromStatus;
  final String? toStatus;
  final String notes;
  final DateTime? timestamp;

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'action': action.name,
      'performedBy': performedBy,
      'performedByName': performedByName,
      'fromDepartment': fromDepartment?.name,
      'toDepartment': toDepartment?.name,
      'fromStatus': fromStatus,
      'toStatus': toStatus,
      'notes': notes,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : null,
    };
  }

  factory OrderHistoryEntry.fromMap(String id, Map<String, dynamic> map) {
    return OrderHistoryEntry(
      id: id,
      orderId: map['orderId'] as String? ?? '',
      action: HistoryAction.fromString(map['action'] as String? ?? 'updated'),
      performedBy: map['performedBy'] as String? ?? '',
      performedByName: map['performedByName'] as String? ?? '',
      fromDepartment: map['fromDepartment'] != null
          ? Department.fromString(map['fromDepartment'] as String)
          : null,
      toDepartment: map['toDepartment'] != null
          ? Department.fromString(map['toDepartment'] as String)
          : null,
      fromStatus: map['fromStatus'] as String?,
      toStatus: map['toStatus'] as String?,
      notes: map['notes'] as String? ?? '',
      timestamp: _parseTimestamp(map['timestamp']),
    );
  }

  factory OrderHistoryEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return OrderHistoryEntry.fromMap(doc.id, doc.data() ?? {});
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
