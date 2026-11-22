import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'session_service.dart';

final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _notificationChannel =
    AndroidNotificationChannel(
  'test2hire_alerts',
  'Test2Hire Notifications',
  description: 'Alerts for job applications, exams, interviews, and offers',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM Background message: ${message.messageId}');
  try {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(settings: initSettings);

    final title =
        message.notification?.title ?? message.data['title'] ?? 'Test2Hire';
    final body = message.notification?.body ??
        message.data['body'] ??
        message.data['message'] ??
        '';

    if (title.isNotEmpty || body.isNotEmpty) {
      await plugin.show(
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'test2hire_alerts',
            'Test2Hire Notifications',
            channelDescription:
                'Alerts for job applications, exams, interviews, and offers',
            importance: Importance.max,
            priority: Priority.high,
            visibility: NotificationVisibility.public,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            showWhen: true,
          ),
        ),
        payload: message.data['actionUrl'] ?? message.data['route'],
      );
    }
  } catch (e) {
    debugPrint('Error in background message handler: $e');
  }
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;

  /// Global callback to trigger in-app banner/dialog when foreground notification arrives
  static void Function(RemoteMessage message)? onForegroundMessageReceived;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Set background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Initialize Flutter Local Notifications for system tray & lockscreen alerts
      const AndroidInitializationSettings androidInitSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings =
          InitializationSettings(android: androidInitSettings);

      await _localNotificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('FCM: User tapped local notification: ${response.payload}');
        },
      );

      final androidPlugin = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(_notificationChannel);
        await androidPlugin.requestNotificationsPermission();
      }

      // 3. Request FCM notification permissions (critical for iOS and Android 13+)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('FCM: User granted permission: ${settings.authorizationStatus}');

      // 4. Set foreground presentation options (shows head-up alert even when app is foregrounded)
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 5. Register current device token
      await registerToken();

      // 6. Listen to token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM: Token refreshed');
        _saveTokenToFirestore(newToken);
      });

      // 7. Handle notification click when app is terminated
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM: Launched from terminated state via notification: ${initialMessage.data}');
      }

      // 8. Handle foreground notifications: display system tray heads-up alert + notify in-app listeners
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM Foreground message: ${message.notification?.title} - ${message.notification?.body}');
        displayMessageNotification(message);
        if (onForegroundMessageReceived != null) {
          onForegroundMessageReceived!(message);
        }
      });

      // 9. Handle notification click when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM: User tapped on notification from background: ${message.data}');
      });

      _initialized = true;
    } catch (e) {
      debugPrint('FCM Initialization error: $e');
    }
  }

  /// Displays a heads-up system tray notification using Flutter Local Notifications
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'test2hire_alerts',
        'Test2Hire Notifications',
        channelDescription:
            'Alerts for job applications, exams, interviews, and offers',
        importance: Importance.max,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        showWhen: true,
      );
      const NotificationDetails details =
          NotificationDetails(android: androidDetails);
      await _localNotificationsPlugin.show(
        id: id ?? (DateTime.now().millisecondsSinceEpoch % 100000),
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  /// Extracts title & body from RemoteMessage (data or notification payload) and shows in system tray
  static Future<void> displayMessageNotification(RemoteMessage message) async {
    try {
      final title =
          message.notification?.title ?? message.data['title'] ?? 'Test2Hire';
      final body = message.notification?.body ??
          message.data['body'] ??
          message.data['message'] ??
          '';
      if (title.isNotEmpty || body.isNotEmpty) {
        await showNotification(
          title: title,
          body: body,
          payload: message.data['actionUrl'] ?? message.data['route'],
          id: message.hashCode,
        );
      }
    } catch (e) {
      debugPrint('Error displaying remote message: $e');
    }
  }

  static String? _lastRegisteredUid;
  static String? _lastRegisteredToken;

  static Future<void> registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        if (kDebugMode) {
          debugPrint('FCM Device Token registered (len=${token.length})');
        }
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      debugPrint('FCM: Failed to fetch token: $e');
    }
  }

  static Future<void> registerTokenForUser(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        if (_lastRegisteredUid == uid && _lastRegisteredToken == token) {
          return;
        }
        if (kDebugMode) {
          debugPrint('FCM Device Token registered for user (len=${token.length})');
        }
        await _saveTokenToFirestoreWithUid(token, uid);
      }
    } catch (e) {
      debugPrint('FCM: Failed to fetch token for user $uid: $e');
    }
  }

  static Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _saveTokenToFirestoreWithUid(token, user.uid);
  }

  static Future<void> _saveTokenToFirestoreWithUid(String token, String uid) async {
    if (_lastRegisteredUid == uid && _lastRegisteredToken == token) {
      return;
    }
    try {
      // Save to user doc in Firestore so Cloud Functions can push to this token
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastFcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Only dual-save to companies doc when the user is a company (or cache is unknown)
      final cachedUser = SessionService.getCachedUser();
      if (cachedUser == null || cachedUser.isCompany) {
        try {
          final companyDoc = await FirebaseFirestore.instance.collection('companies').doc(uid).get();
          if (companyDoc.exists) {
            await FirebaseFirestore.instance.collection('companies').doc(uid).set({
              'fcmTokens': FieldValue.arrayUnion([token]),
              'lastFcmToken': token,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        } catch (_) {}
      }

      _lastRegisteredUid = uid;
      _lastRegisteredToken = token;
      debugPrint('FCM: Successfully registered token for user $uid');
    } catch (e) {
      debugPrint('FCM: Error saving token to Firestore: $e');
    }
  }

  static Future<void> removeToken() async {
    _lastRegisteredUid = null;
    _lastRegisteredToken = null;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await _messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });

        final companyDoc = await FirebaseFirestore.instance.collection('companies').doc(user.uid).get();
        if (companyDoc.exists) {
          await FirebaseFirestore.instance.collection('companies').doc(user.uid).update({
            'fcmTokens': FieldValue.arrayRemove([token]),
          });
        }
      }
    } catch (e) {
      debugPrint('FCM: Error removing token: $e');
    }
  }
}
