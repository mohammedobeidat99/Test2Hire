import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for Test2Hire.
/// Generated via FlutterFire CLI or manually configured.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.windows:
        return web;
      case TargetPlatform.linux:
        return web;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD13nxqjaXdtUoAepn1OpF4b8flBFTSozM',
    appId: '1:326304038955:web:2cdc5604a437527314ea6e',
    messagingSenderId: '326304038955',
    projectId: 'test2here-72346',
    authDomain: 'test2here-72346.firebaseapp.com',
    storageBucket: 'test2here-72346.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCQjm1VOnZVVyO6Dusk_k5VpWMNA59jykM',
    appId: '1:326304038955:android:152a0f1a99a8e02a14ea6e',
    messagingSenderId: '326304038955',
    projectId: 'test2here-72346',
    storageBucket: 'test2here-72346.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBheFJeesD7qTz0gyx2MMrB_s3vtMM6mUQ',
    appId: '1:326304038955:ios:deaf110cbf26883114ea6e',
    messagingSenderId: '326304038955',
    projectId: 'test2here-72346',
    storageBucket: 'test2here-72346.firebasestorage.app',
    iosBundleId: 'com.test2hire.mobileApp',
  );

}