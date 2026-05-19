// lib/firebase_options.dart
//
// ============================================================================
// ⚠️  REQUIRED: this file contains PLACEHOLDERS, not real Firebase config.
// The app will boot but Firestore writes will silently fail until you run:
//
//     dart pub global activate flutterfire_cli
//     flutterfire configure
//
// This regenerates the file with your project's real apiKey / appId / etc.
// Without it, AlertService falls back to mock data and reportHazard() no-ops.
// ============================================================================

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web not supported in this project.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// ──────────────────────────────────────────────────────────────────────
  ///  ANDROID  –  replace every value with your google-services.json values
  /// ──────────────────────────────────────────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: 'YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );

  /// ──────────────────────────────────────────────────────────────────────
  ///  iOS  –  replace every value with your GoogleService-Info.plist values
  /// ──────────────────────────────────────────────────────────────────────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
    iosClientId: 'YOUR_IOS_CLIENT_ID',
    iosBundleId: 'com.yourcompany.speedBreakerAlert',
  );
}
