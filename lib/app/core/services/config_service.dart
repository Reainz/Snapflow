import 'package:get/get.dart';

class ConfigService extends GetxService {
  String get cloudinaryCloudName {
    const v = String.fromEnvironment('CLOUDINARY_CLOUD_NAME', defaultValue: '');
    return v;
  }

  String get cloudinaryApiKey {
    const v = String.fromEnvironment('CLOUDINARY_API_KEY', defaultValue: '');
    return v;
  }

  String get cloudinaryApiSecret {
    const v = String.fromEnvironment('CLOUDINARY_API_SECRET', defaultValue: '');
    return v;
  }

  // Firebase Web configuration (provide via --dart-define)
  String get firebaseApiKey {
    const v = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
    return v;
  }

  String get firebaseAppId {
    const v = String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');
    return v;
  }

  String get firebaseProjectId {
    const v = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
    return v;
  }

  String get firebaseMessagingSenderId {
    const v = String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '',
    );
    return v;
  }

  String get firebaseAuthDomain {
    const v = String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: '');
    return v;
  }

  String get firebaseStorageBucket {
    const v = String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: '',
    );
    return v;
  }

  String get firebaseMeasurementId {
    const v = String.fromEnvironment(
      'FIREBASE_MEASUREMENT_ID',
      defaultValue: '',
    );
    return v;
  }

  // OAuth client ID for Google Sign-In (Web)
  String get firebaseWebClientId {
    const v = String.fromEnvironment(
      'FIREBASE_WEB_CLIENT_ID',
      defaultValue: '',
    );
    return v;
  }

  String get firebaseServerClientId {
    const explicit = String.fromEnvironment(
      'FIREBASE_SERVER_CLIENT_ID',
      defaultValue: '',
    );

    if (explicit.isNotEmpty) {
      return explicit;
    }

    // Fallback to the web client ID since Firebase generates the same
    // OAuth client for Android server flows by default.
    final webClient = firebaseWebClientId;
    return webClient;
  }

  // reCAPTCHA v3 site key for Firebase App Check on Web
  String get firebaseRecaptchaV3SiteKey {
    const v = String.fromEnvironment(
      'FIREBASE_RECAPTCHA_V3_SITE_KEY',
      defaultValue: '',
    );
    return v;
  }
}
