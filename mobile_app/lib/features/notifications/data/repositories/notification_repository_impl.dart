import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote_data_source.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource _remoteDataSource;

  NotificationRepositoryImpl({required NotificationRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Stream<List<NotificationItem>> listenNotifications(String userId) {
    return _remoteDataSource.listenNotifications(userId);
  }

  @override
  Future<List<NotificationItem>> getNotifications(String userId) async {
    try {
      return await _remoteDataSource.getNotifications(userId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to fetch notifications.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      await _remoteDataSource.markAsRead(notificationId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to mark notification read.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    try {
      await _remoteDataSource.markAllAsRead(userId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to mark all notifications read.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _remoteDataSource.deleteNotification(notificationId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to delete notification.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> clearAllNotifications(String userId) async {
    try {
      await _remoteDataSource.clearAllNotifications(userId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to clear all notifications.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> registerDeviceToken(String token, {String? platform}) async {
    await _remoteDataSource.registerDeviceToken(token, platform: platform);
  }

  @override
  Future<void> unregisterDeviceToken(String token) async {
    await _remoteDataSource.unregisterDeviceToken(token);
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
    try {
      await _remoteDataSource.sendNotification(
        userId: userId,
        title: title,
        body: body,
        type: type,
        actionUrl: actionUrl,
        data: data,
      );
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to send notification.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
