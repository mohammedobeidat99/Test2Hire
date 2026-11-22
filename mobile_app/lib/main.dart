import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'core/services/fcm_service.dart';
import 'core/services/firebase_service.dart';
import 'core/services/session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🚨 [ERROR]: ${details.exception}');
    final st = details.stack?.toString().split('\n') ?? [];
    for (int i = 0; i < (st.length > 10 ? 10 : st.length); i++) {
      debugPrint('   #$i: ${st[i]}');
    }
  };

  try {
    await Future.wait([
      initializeDateFormatting('en'),
      initializeDateFormatting('ar'),
    ]);
  } catch (e) {
    debugPrint('Could not initialize date formatting: $e');
  }

  
  

  try {
    await FirebaseService.initialize(useEmulators: false);
    await SessionService.init();
    unawaited(FcmService.initialize().catchError((e) {
      debugPrint('FCM deferred initialization error: $e');
    }));
  } catch (e) {

    debugPrint('Firebase not connected yet, running in offline/scaffold mode: $e');
    await SessionService.init();
  }

  runApp(const Test2HireApp());
}
