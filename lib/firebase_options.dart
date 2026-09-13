// File generated from google-services.json (Android)
// iOS values: GoogleService-Info.plist se update karo jab available ho

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      default:
        return ios;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCttp_KbRpA2gR6S8Ub3qTFQwi6QXnn_8A',
    appId: '1:356786241093:android:f0e73cc5a3c3a043782d2c',
    messagingSenderId: '356786241093',
    projectId: 'aivision-969f3',
    storageBucket: 'aivision-969f3.firebasestorage.app',
  );

  // iOS: GoogleService-Info.plist se flutterfire configure run karo
  // Tab tak Android ke values use ho rahe hain (iOS build ke liye update karna)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCttp_KbRpA2gR6S8Ub3qTFQwi6QXnn_8A',
    appId: '1:356786241093:ios:f0e73cc5a3c3a043782d2c',
    messagingSenderId: '356786241093',
    projectId: 'aivision-969f3',
    storageBucket: 'aivision-969f3.firebasestorage.app',
    iosClientId: '356786241093-kavs7cjhlkgb0j1nh94anran5fbk7ree.apps.googleusercontent.com',
    iosBundleId: 'com.aivideo.aiVideoGenerator',
  );
}
