import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_constants.dart';
import '../models/enums/audit_action.dart';
import '../models/system_audit_log_entry.dart';
import '../utils/exceptions/exceptions.dart';

class AuditService {
  AuditService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection(FirestoreConstants.auditLog);

  Future<void> log({
    required AuditAction action,
    required String performedBy,
    required String performedByName,
    String entityType = '',
    String entityId = '',
    String notes = '',
  }) async {
    try {
      await _ref.add({
        'action': action.name,
        'performedBy': performedBy,
        'performedByName': performedByName,
        'entityType': entityType,
        'entityId': entityId,
        'notes': notes,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to write audit log',
        code: e.code,
      );
    }
  }

  Stream<List<SystemAuditLogEntry>> watchRecent({int limit = 100}) {
    return _ref
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(SystemAuditLogEntry.fromFirestore)
              .toList(),
        );
  }

  Future<List<SystemAuditLogEntry>> fetchRecent({int limit = 200}) async {
    final snapshot = await _ref
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(SystemAuditLogEntry.fromFirestore).toList();
  }
}
