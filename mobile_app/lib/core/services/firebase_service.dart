import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

class FirebaseService {
  static Future<void> initialize({bool useEmulators = false}) async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      if (useEmulators) {
        await _connectToEmulators();
      }

      debugPrint('FirebaseService: Successfully initialized Firebase.');
    } catch (e) {
      debugPrint('FirebaseService: Error initializing Firebase: $e');
      rethrow;
    }
  }

  static Future<void> _connectToEmulators() async {
    // Emulator host IP: 10.0.2.2 for Android emulator, localhost for iOS/web
    const host = kIsWeb ? 'localhost' : '10.0.2.2';

    try {
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      await FirebaseStorage.instance.useStorageEmulator(host, 9199);
      debugPrint('FirebaseService: Connected to Firebase Local Emulators on $host');
    } catch (e) {
      debugPrint('FirebaseService: Failed to connect to emulators: $e');
    }
  }
}
