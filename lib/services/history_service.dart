import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_constants.dart';
import '../models/order_history_entry.dart';
import '../utils/exceptions/exceptions.dart';

class HistoryService {
  HistoryService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _historyRef =>
      _firestore.collection(FirestoreConstants.orderHistory);

  Future<void> logEntry(OrderHistoryEntry entry) async {
    try {
      await _historyRef.add(entry.toMap());
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to log history entry',
        code: e.code,
      );
    }
  }

  Stream<List<OrderHistoryEntry>> watchOrderHistory(
    String orderId, {
    int limit = 100,
  }) {
    return _historyRef
        .where('orderId', isEqualTo: orderId)
        .snapshots()
        .map((snapshot) => _sortAndLimitHistory(snapshot.docs, limit));
  }

  Future<List<OrderHistoryEntry>> getOrderHistory(String orderId) async {
    final snapshot = await _historyRef
        .where('orderId', isEqualTo: orderId)
        .get();
    return _sortAndLimitHistory(snapshot.docs, 100);
  }

  List<OrderHistoryEntry> _sortAndLimitHistory(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int limit,
  ) {
    final entries = docs.map(OrderHistoryEntry.fromFirestore).toList()
      ..sort((a, b) {
        final aTime = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
    if (entries.length <= limit) return entries;
    return entries.sublist(0, limit);
  }

  Future<List<OrderHistoryEntry>> getRecentHistory({int limit = 20}) async {
    final snapshot = await _historyRef
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => OrderHistoryEntry.fromFirestore(doc))
        .toList();
  }
}
