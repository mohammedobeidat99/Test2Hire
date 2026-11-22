import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/notification_item.dart';

class NotificationModel extends NotificationItem {
  const NotificationModel({
    required super.id,
    required super.userId,
    required super.title,
    required super.body,
    super.type = NotificationType.system,
    super.actionUrl,
    super.entityId,
    super.data,
    super.isRead = false,
    super.createdAt,
    super.readAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return NotificationModel.fromMap(data, doc.id);
  }

  factory NotificationModel.fromMap(Map<String, dynamic> data, [String? id]) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return NotificationModel(
      id: id ?? data['id'] ?? '',
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: NotificationTypeX.fromServerString(data['type'] as String?),
      actionUrl: data['actionUrl'] as String?,
      entityId: data['entityId'] as String?,
      data: data['data'] is Map ? Map<String, dynamic>.from(data['data'] as Map) : null,
      isRead: data['isRead'] == true,
      createdAt: parseDate(data['createdAt']),
      readAt: parseDate(data['readAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'type': type.toServerString(),
      'actionUrl': actionUrl,
      if (entityId != null) 'entityId': entityId,
      if (data != null) 'data': data,
      'isRead': isRead,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
    };
  }
}
