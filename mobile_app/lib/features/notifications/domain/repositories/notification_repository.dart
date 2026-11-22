import '../entities/notification_item.dart';

abstract class NotificationRepository {
  Stream<List<NotificationItem>> listenNotifications(String userId);
  Future<List<NotificationItem>> getNotifications(String userId);
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
