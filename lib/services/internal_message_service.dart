import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_constants.dart';
import '../models/app_user.dart';
import '../models/enums/department.dart';
import '../models/enums/message_priority.dart';
import '../models/enums/message_type.dart';
import '../models/enums/recipient_scope.dart';
import '../models/internal_message.dart';
import '../utils/exceptions/exceptions.dart';

class InternalMessageService {
  InternalMessageService(this._firestore, this._collectionName);

  final FirebaseFirestore _firestore;
  final String _collectionName;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection(_collectionName);

  Future<void> sendMessage({
    required AppUser sender,
    required String title,
    required String message,
    required MessageType type,
    required MessagePriority priority,
    required RecipientScope scope,
    String? receiverId,
    String? receiverName,
    Department? department,
  }) async {
    try {
      await _ref.add({
        'title': title.trim(),
        'message': message.trim(),
        'senderId': sender.uid,
        'senderName': sender.displayName,
        'type': type.name,
        'priority': priority.name,
        'recipientScope': scope.name,
        'receiverId': receiverId,
        'receiverName': receiverName,
        'department': department?.name,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to send message',
        code: e.code,
      );
    }
  }

  Stream<List<InternalMessage>> watchMessagesForUser(AppUser user) {
    return _ref
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map(
                (doc) => InternalMessage.fromFirestore(
                  doc,
                  collection: _collectionName,
                ),
              )
              .where((message) => _isVisibleToUser(message, user))
              .toList();
          return messages;
        });
  }

  Stream<int> watchUnreadCount(AppUser user) {
    return watchMessagesForUser(user).map(
      (messages) => messages.where((message) => !message.isRead).length,
    );
  }

  Future<void> markAsRead(String messageId) async {
    try {
      await _ref.doc(messageId).update({'isRead': true});
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to mark message as read',
        code: e.code,
      );
    }
  }

  Future<void> markAllAsRead(AppUser user) async {
    final snapshot = await _ref.orderBy('createdAt', descending: true).get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      final message = InternalMessage.fromFirestore(
        doc,
        collection: _collectionName,
      );
      if (_isVisibleToUser(message, user) && !message.isRead) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _ref.doc(messageId).delete();
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to delete message',
        code: e.code,
      );
    }
  }

  bool _isVisibleToUser(InternalMessage message, AppUser user) {
    return switch (message.recipientScope) {
      RecipientScope.everyone => true,
      RecipientScope.singleEmployee => message.receiverId == user.uid,
      RecipientScope.department =>
        message.department != null &&
            user.department != null &&
            message.department == user.department,
    };
  }
}

class NotificationService extends InternalMessageService {
  NotificationService(FirebaseFirestore firestore)
      : super(firestore, FirestoreConstants.notifications);
}

class AlertService extends InternalMessageService {
  AlertService(FirebaseFirestore firestore)
      : super(firestore, FirestoreConstants.alerts);
}
