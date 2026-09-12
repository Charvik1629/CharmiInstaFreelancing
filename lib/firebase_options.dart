// Generated from the project's google-services.json + GoogleService-Info.plist
// (Firebase project nexveero-1e4f0). Equivalent to `flutterfire configure`
// output. If you re-run the FlutterFire CLI later it will overwrite this.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for the current platform.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured for Nexveero.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'FirebaseOptions are not configured for $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDLJvNYtcRQMqtnGDlTdw3-tGroapfi9PQ',
    appId: '1:904914412878:android:4c0ab0384ee917f2c32a1f',
    messagingSenderId: '904914412878',
    projectId: 'nexveero-1e4f0',
    storageBucket: 'nexveero-1e4f0.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBWqnNMdxm8mUKoIfswNqC3dcBpBFjl_lo',
    appId: '1:904914412878:ios:b4757c0c66cf928ac32a1f',
    messagingSenderId: '904914412878',
    projectId: 'nexveero-1e4f0',
    storageBucket: 'nexveero-1e4f0.firebasestorage.app',
    iosBundleId: 'com.nexveero.app',
  );
}
