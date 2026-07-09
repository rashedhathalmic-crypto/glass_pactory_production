import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums/department.dart';
import 'enums/message_priority.dart';
import 'enums/message_type.dart';
import 'enums/recipient_scope.dart';

class InternalMessage {
  const InternalMessage({
    required this.id,
    required this.title,
    required this.message,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.priority,
    required this.recipientScope,
    this.receiverId,
    this.receiverName,
    this.department,
    this.isRead = false,
    this.createdAt,
    this.collection = 'notifications',
  });

  final String id;
  final String title;
  final String message;
  final String senderId;
  final String senderName;
  final MessageType type;
  final MessagePriority priority;
  final RecipientScope recipientScope;
  final String? receiverId;
  final String? receiverName;
  final Department? department;
  final bool isRead;
  final DateTime? createdAt;
  final String collection;

  InternalMessage copyWith({
    String? id,
    String? title,
    String? message,
    bool? isRead,
  }) {
    return InternalMessage(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      senderId: senderId,
      senderName: senderName,
      type: type,
      priority: priority,
      recipientScope: recipientScope,
      receiverId: receiverId,
      receiverName: receiverName,
      department: department,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      collection: collection,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'senderId': senderId,
      'senderName': senderName,
      'type': type.name,
      'priority': priority.name,
      'recipientScope': recipientScope.name,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'department': department?.name,
      'isRead': isRead,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }

  factory InternalMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String collection,
  }) {
    final data = doc.data() ?? {};
    return InternalMessage(
      id: doc.id,
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      type: MessageType.fromString(data['type'] as String? ?? 'general'),
      priority: MessagePriority.fromString(
        data['priority'] as String? ?? 'normal',
      ),
      recipientScope: RecipientScope.fromString(
        data['recipientScope'] as String? ?? 'everyone',
      ),
      receiverId: data['receiverId'] as String?,
      receiverName: data['receiverName'] as String?,
      department: data['department'] != null
          ? Department.fromString(data['department'] as String)
          : null,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: _parseTimestamp(data['createdAt']),
      collection: collection,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
