import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Firebase configuration for the current platform.
///
/// This file was generated from your Android google-services.json to enable
/// initialization without running FlutterFire CLI for other platforms.
/// To fully support iOS/Web/MacOS/Windows/Linux, run `flutterfire configure`.
class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    // Do not access dart:io Platform on the web – it throws at runtime.
    if (kIsWeb) {
      return null; // Web not configured yet – run `flutterfire configure` to add.
    }

    if (Platform.isAndroid) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyDN6Tlko1InF1uDTO11KiyWmZwpfDHka0Y',
        appId: '1:104537550413:android:47701b03ad015240b33604',
        messagingSenderId: '104537550413',
        projectId: 'snapflow-4577d',
        storageBucket: 'snapflow-4577d.firebasestorage.app',
      );
    }

    if (Platform.isIOS || Platform.isMacOS) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyBdS2bqWUn-8RIGN3YhoAZAQlh7UmlLlnA',
        appId: '1:104537550413:ios:5521ea034740deb9b33604',
        messagingSenderId: '104537550413',
        projectId: 'snapflow-4577d',
        storageBucket: 'snapflow-4577d.firebasestorage.app',
        iosBundleId: 'com.snapflow.app',
      );
    }
    // Other platforms not configured yet.
    return null;
  }
}
