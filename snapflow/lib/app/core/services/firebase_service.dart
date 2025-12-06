import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';

class FirebaseService extends GetxService {
  bool get isInitialized => _initialized;

  bool _initialized = false;

  Future<void> init({
    FirebaseOptions? options,
    bool enableAppCheck = false,
    String? webRecaptchaV3SiteKey,
    bool fatalOnError = false,
  }) async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp(options: options);

      if (enableAppCheck) {
        await FirebaseAppCheck.instance.activate(
          webProvider: webRecaptchaV3SiteKey != null
              ? ReCaptchaV3Provider(webRecaptchaV3SiteKey)
              : null,
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.debug,
        );
        try {
          final t = await FirebaseAppCheck.instance.getToken(true);
          Get.log('AppCheck token (debug): ${t?.substring(0, 12)}.');
        } catch (e) {
          Get.log('AppCheck token fetch failed: $e', isError: true);
        }
      }

      _initialized = true;

      // Enable Firestore offline persistence and reasonable cache size
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      } catch (e) {
        Get.log('Firestore persistence setup failed (ignored): $e');
      }
    } catch (error, stackTrace) {
      Get.log(
        'Firebase initialization failed: $error\n$stackTrace',
        isError: true,
      );
      if (fatalOnError) rethrow;
    }
  }
}
