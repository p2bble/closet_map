import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not supported.');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Unsupported platform: $defaultTargetPlatform');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA-iqYNbdpBdtS4oKH7QSyoiWEjL9tWW0E',
    appId: '1:296040221341:android:5afa94e892bd7aeac8a274',
    messagingSenderId: '296040221341',
    projectId: 'p2bble-closet-map',
    storageBucket: 'p2bble-closet-map.firebasestorage.app',
  );
}
