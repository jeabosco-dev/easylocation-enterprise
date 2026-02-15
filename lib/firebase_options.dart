import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBhm2zRZ3ZwpVepnQO8p_uu8ho4gU5g9d4',
    appId: '1:540611988411:web:922ba2df8746edce5a529e',
    messagingSenderId: '540611988411',
    projectId: 'easylocation-be28b',
    authDomain: 'easylocation-be28b.firebaseapp.com',
    storageBucket: 'easylocation-be28b.firebasestorage.app',
    measurementId: 'G-QDE23FP54E',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB3k9CvIS9hz_o9jayRVaofeENN1YnF6Qc',
    appId: '1:540611988411:android:28daa77497e234585a529e',
    messagingSenderId: '540611988411',
    projectId: 'easylocation-be28b',
    storageBucket: 'easylocation-be28b.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB3k9CvIS9hz_o9jayRVaofeENN1YnF6Qc',
    appId: '1:540611988411:ios:22757a3300bf2a735a529e',
    messagingSenderId: '540611988411',
    projectId: 'easylocation-be28b',
    storageBucket: 'easylocation-be28b.firebasestorage.app',
    iosBundleId: 'com.easylocation.app',
  );
}