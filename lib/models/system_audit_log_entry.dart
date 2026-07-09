import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums/audit_action.dart';

class SystemAuditLogEntry {
  const SystemAuditLogEntry({
    required this.id,
    required this.action,
    required this.performedBy,
    required this.performedByName,
    this.entityType = '',
    this.entityId = '',
    this.notes = '',
    this.timestamp,
  });

  final String id;
  final AuditAction action;
  final String performedBy;
  final String performedByName;
  final String entityType;
  final String entityId;
  final String notes;
  final DateTime? timestamp;

  Map<String, dynamic> toMap() {
    return {
      'action': action.name,
      'performedBy': performedBy,
      'performedByName': performedByName,
      'entityType': entityType,
      'entityId': entityId,
      'notes': notes,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : null,
    };
  }

  factory SystemAuditLogEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return SystemAuditLogEntry(
      id: doc.id,
      action: AuditAction.fromString(data['action'] as String? ?? 'userActivity'),
      performedBy: data['performedBy'] as String? ?? '',
      performedByName: data['performedByName'] as String? ?? '',
      entityType: data['entityType'] as String? ?? '',
      entityId: data['entityId'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      timestamp: _parseTimestamp(data['timestamp']),
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
