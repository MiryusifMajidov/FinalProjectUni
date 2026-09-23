// GENERATED FILE — Replace with your actual Firebase config.
// Run: flutterfire configure
// See: https://firebase.flutter.dev/docs/cli

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

  // TODO: Replace ALL values below with your project's actual Firebase config.
  // Get these from: Firebase Console → Project Settings → Your apps

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDM6tG1CffTElqZbSetrNn0BCiwo9yRzPU',
    appId: '1:544347300592:web:836f257e00bcaf089f1835',
    messagingSenderId: '544347300592',
    projectId: 'chess-ac4eb',
    authDomain: 'chess-ac4eb.firebaseapp.com',
    storageBucket: 'chess-ac4eb.firebasestorage.app',
    measurementId: 'G-SS9DM7BEZD',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyATIGXSCXd0FAHHNwtMsJGCUGzWjhQAaz4',
    appId: '1:544347300592:android:3fbbefee62a882139f1835',
    messagingSenderId: '544347300592',
    projectId: 'chess-ac4eb',
    storageBucket: 'chess-ac4eb.firebasestorage.app',
  );

  // Mirrors ios/Runner/GoogleService-Info.plist for the iOS app registered
  // under com.ludodo.checkmate. On iOS, Firebase.initializeApp() reads THESE
  // values rather than the plist, so the two must agree: appId here is the
  // plist's GOOGLE_APP_ID and apiKey is its API_KEY. (The plist is still
  // required — the native SDK reads REVERSED_CLIENT_ID from it for Google
  // Sign-In.) The earlier registration under com.chessapp.chessApp is dead;
  // that bundle id was unavailable on the Apple Developer portal.
  //
  // databaseURL is deliberately absent: realtime_game_service.dart passes it
  // explicitly to FirebaseDatabase.instanceFor().
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCcbZEUfhg8lzxicUgLhljfk9I2LiK_IR0',
    appId: '1:544347300592:ios:61a92917b3d6402c9f1835',
    messagingSenderId: '544347300592',
    projectId: 'chess-ac4eb',
    storageBucket: 'chess-ac4eb.firebasestorage.app',
    iosBundleId: 'com.ludodo.checkmate',
  );

}