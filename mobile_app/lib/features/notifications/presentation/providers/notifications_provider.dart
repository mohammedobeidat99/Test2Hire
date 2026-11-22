import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mobile_app/core/services/fcm_service.dart';
import 'package:mobile_app/features/notifications/domain/entities/notification_item.dart';
import 'package:mobile_app/features/notifications/domain/repositories/notification_repository.dart';

class NotificationsProvider extends ChangeNotifier {
  final NotificationRepository _repository;

  List<NotificationItem> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<NotificationItem>>? _streamSubscription;
  String? _currentUserId;

  NotificationsProvider({required NotificationRepository repository})
      : _repository = repository;

  List<NotificationItem> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<NotificationItem> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();

  int get unreadCount => unreadNotifications.length;

  void reset() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _currentUserId = null;
    _notifications = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void listenToNotifications(String userId, {bool force = false}) {
    if (!force && _currentUserId == userId && _streamSubscription != null) {
      return;
    }
    if (_currentUserId != null && _currentUserId != userId) {
      _notifications = [];
    }
    _currentUserId = userId;
    _streamSubscription?.cancel();
    _isLoading = _notifications.isEmpty;
    _errorMessage = null;
    notifyListeners();

    _streamSubscription = _repository.listenNotifications(userId).listen(
      (items) {
        if (_currentUserId != userId) return;
        // Trigger system notification when a new unread notification arrives
        if (_notifications.isNotEmpty) {
          final oldIds = _notifications.map((n) => n.id).toSet();
          final newItems = items
              .where((n) => !oldIds.contains(n.id) && !n.isRead)
              .toList();
          for (final newItem in newItems) {
            FcmService.showNotification(
              title: newItem.title,
              body: newItem.body,
              payload: newItem.actionUrl,
              id: newItem.id.hashCode,
            );
          }
        }
        _notifications = items;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  Future<void> refreshNotifications([String? userId]) async {
    final targetId = userId ?? _currentUserId;
    if (targetId == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final items = await _repository.getNotifications(targetId);
      _notifications = items;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendTestNotification(String userId) async {
    try {
      await _repository.sendNotification(
        userId: userId,
        title: 'إشعار تجريبي ناجح! 🔔',
        body: 'نظام التنبيهات يعمل بنجاح وكفاءة في التطبيق الآن.',
        type: NotificationType.system,
      );
      // Immediately show local notification in system tray & lockscreen
      await FcmService.showNotification(
        title: 'إشعار تجريبي ناجح! 🔔',
        body: 'نظام التنبيهات يعمل بنجاح وكفاءة في التطبيق الآن.',
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clear() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _currentUserId = null;
    _notifications = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _repository.markAsRead(notificationId);
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(
          isRead: true,
          readAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    if (_currentUserId == null) return;
    try {
      await _repository.markAllAsRead(_currentUserId!);
      _notifications = _notifications.map((n) {
        return n.copyWith(isRead: true, readAt: DateTime.now());
      }).toList();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _repository.deleteNotification(notificationId);
      _notifications.removeWhere((n) => n.id == notificationId);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> clearAllNotifications() async {
    if (_currentUserId == null) return false;
    try {
      await _repository.clearAllNotifications(_currentUserId!);
      _notifications.clear();
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> registerDeviceToken(String token, {String? platform}) async {
    try {
      await _repository.registerDeviceToken(token, platform: platform);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> unregisterDeviceToken(String token) async {
    try {
      await _repository.unregisterDeviceToken(token);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}
