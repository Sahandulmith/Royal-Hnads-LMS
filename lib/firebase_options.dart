import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCsvkTzFj0k6ES0TUKPOdF5Tb5gdEu7aQg',
    appId: '1:1033785248522:web:1884b9e942a57de64d08f3',
    messagingSenderId: '1033785248522',
    projectId: 'royal-hand-lms',
    authDomain: 'royal-hand-lms.firebaseapp.com',
    storageBucket: 'royal-hand-lms.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCsvkTzFj0k6ES0TUKPOdF5Tb5gdEu7aQg',
    appId: '1:1033785248522:android:1884b9e942a57de64d08f3',
    messagingSenderId: '1033785248522',
    projectId: 'royal-hand-lms',
    storageBucket: 'royal-hand-lms.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCsvkTzFj0k6ES0TUKPOdF5Tb5gdEu7aQg',
    appId: '1:1033785248522:ios:1884b9e942a57de64d08f3',
    messagingSenderId: '1033785248522',
    projectId: 'royal-hand-lms',
    storageBucket: 'royal-hand-lms.firebasestorage.app',
    iosBundleId: 'com.sahan.lms',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCsvkTzFj0k6ES0TUKPOdF5Tb5gdEu7aQg',
    appId: '1:1033785248522:ios:1884b9e942a57de64d08f3',
    messagingSenderId: '1033785248522',
    projectId: 'royal-hand-lms',
    storageBucket: 'royal-hand-lms.firebasestorage.app',
    iosBundleId: 'com.sahan.lms',
  );
}
