import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../domain/entities/notification_item.dart';
import '../models/notification_model.dart';

abstract class NotificationRemoteDataSource {
  Stream<List<NotificationModel>> listenNotifications(String userId);
  Future<List<NotificationModel>> getNotifications(String userId);
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead(String userId);
  Future<void> deleteNotification(String notificationId);
  Future<void> clearAllNotifications(String userId);
  Future<void> registerDeviceToken(String token, {String? platform});
  Future<void> unregisterDeviceToken(String token);
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    NotificationType type,
    String? actionUrl,
    Map<String, dynamic>? data,
  });
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  NotificationRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  CollectionReference get _notifCol => _firestore.collection('notifications');

  @override
  Stream<List<NotificationModel>> listenNotifications(String userId) {
    return _notifCol
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => NotificationModel.fromFirestore(d)).toList();
      list.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  @override
  Future<List<NotificationModel>> getNotifications(String userId) async {
    try {
      final query = await _notifCol
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return query.docs.map((d) => NotificationModel.fromFirestore(d)).toList();
    } catch (_) {
      final query = await _notifCol
          .where('userId', isEqualTo: userId)
          .get();
      final list = query.docs.map((d) => NotificationModel.fromFirestore(d)).toList();
      list.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return list;
    }
  }

  @override
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    NotificationType type = NotificationType.system,
    String? actionUrl,
    Map<String, dynamic>? data,
  }) async {
    final docRef = _notifCol.doc();
    await docRef.set({
      'id': docRef.id,
      'userId': userId,
      'title': title,
      'body': body,
      'type': type.toServerString(),
      'actionUrl': actionUrl,
      'data': ?data,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _notifCol.doc(notificationId).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static const int _maxBatchSize = 450;

  @override
  Future<void> markAllAsRead(String userId) async {
    final unread = await _notifCol
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    if (unread.docs.isEmpty) return;

    for (var i = 0; i < unread.docs.length; i += _maxBatchSize) {
      final chunk = unread.docs.skip(i).take(_maxBatchSize);
      final batch = _firestore.batch();
      for (final doc in chunk) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    await _notifCol.doc(notificationId).delete();
  }

  @override
  Future<void> clearAllNotifications(String userId) async {
    final snap = await _notifCol.where('userId', isEqualTo: userId).get();
    if (snap.docs.isEmpty) return;
    for (var i = 0; i < snap.docs.length; i += _maxBatchSize) {
      final chunk = snap.docs.skip(i).take(_maxBatchSize);
      final batch = _firestore.batch();
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  @override
  Future<void> registerDeviceToken(String token, {String? platform}) async {
    try {
      final callable = _functions.httpsCallable('saveFcmToken');
      await callable.call({
        'token': token,
        'platform': platform ?? 'android',
      });
    } catch (_) {
      // Ignored for environments without cloud functions / local testing
    }
  }

  @override
  Future<void> unregisterDeviceToken(String token) async {
    try {
      final callable = _functions.httpsCallable('removeFcmToken');
      await callable.call({
        'token': token,
      });
    } catch (_) {
      // Ignored
    }
  }
}
