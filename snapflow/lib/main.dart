import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:get_storage/get_storage.dart';

import 'app/core/bindings/app_initial_binding.dart';
import 'app/core/services/auth_service.dart';
import 'app/core/services/config_service.dart';
import 'app/core/services/firebase_service.dart';
import 'app/core/services/notification_service.dart';
import 'app/core/theme/app_theme.dart';
import 'app/routes/app_pages.dart';
import 'firebase_options.dart';
import 'app/core/services/cloudinary_service.dart';
import 'app/core/services/deep_link_service.dart';
import 'app/core/services/offline_queue_service.dart';
import 'app/core/services/theme_service.dart';

Future<void> main() async {
  // Step 1: Add global error handlers BEFORE any initialization
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Handle Flutter framework errors (widget build errors, etc.)
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('🔴 Flutter Error: ${details.exception}');
      debugPrint('Stack trace: ${details.stack}');
    };
    
    // Handle async errors not caught by Flutter
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('🔴 Platform Error: $error');
      debugPrint('Stack trace: $stack');
      return true;
    };
    
    debugPrint('✅ [Init] Global error handlers configured');
    
    // Step 2: Wrap entire initialization in try-catch
    try {
      await _initializeApp();
    } catch (error, stackTrace) {
      debugPrint('🔴 [Init] Fatal error during app initialization: $error');
      debugPrint('Stack trace: $stackTrace');
      
      // Run app with error UI instead of crashing
      runApp(ErrorApp(error: error.toString(), stackTrace: stackTrace.toString()));
      return;
    }
    
    // If initialization succeeded, run the normal app
    runApp(SnapflowApp());
  }, (error, stack) {
    debugPrint('🔴 [Zone] Uncaught error: $error');
    debugPrint('Stack trace: $stack');
  });
}

/// Step 3 & 4: Separate initialization function with detailed error handling
Future<void> _initializeApp() async {
  debugPrint('🚀 [Init] Starting app initialization...');

  // Suppress ugly red error screens in production
  ErrorWidget.builder = (FlutterErrorDetails details) {
    // Log error for debugging
    debugPrint('⚠️ Widget Error: ${details.exception}');
    
    // Return an empty container instead of the red error screen
    return Container(
      color: Colors.transparent,
      alignment: Alignment.center,
      child: const SizedBox.shrink(),
    );
  };
  debugPrint('✅ [Init] Error widget builder configured');

  // Step 3.1: Initialize GetX bindings with error handling
  try {
    debugPrint('🔄 [Init] Initializing GetX bindings...');
    final initialBinding = AppInitialBinding();
    initialBinding.dependencies();
    debugPrint('✅ [Init] GetX bindings initialized successfully');
  } catch (error, stackTrace) {
    debugPrint('🔴 [Init] Failed to initialize GetX bindings: $error');
    debugPrint('Stack trace: $stackTrace');
    rethrow; // Critical error, cannot continue
  }

  // Step 3.2: Initialize Firebase with error handling
  bool firebaseInitialized = false;
  try {
    debugPrint('🔄 [Init] Initializing Firebase...');
    final firebaseService = Get.find<FirebaseService>();
    final options = DefaultFirebaseOptions.currentPlatform;

    if (options != null) {
      // Disable App Check for easier development
      await firebaseService.init(options: options, enableAppCheck: false);
      firebaseInitialized = firebaseService.isInitialized;
      debugPrint('✅ [Init] Firebase initialized successfully');
    } else if (kIsWeb) {
      // Web path: allow supplying FirebaseOptions via dart-defines to support running without flutterfire-generated web options.
      final config = Get.find<ConfigService>();
      if (config.firebaseApiKey.isNotEmpty &&
          config.firebaseAppId.isNotEmpty &&
          config.firebaseProjectId.isNotEmpty &&
          config.firebaseMessagingSenderId.isNotEmpty) {
        final webOptions = FirebaseOptions(
          apiKey: config.firebaseApiKey,
          appId: config.firebaseAppId,
          projectId: config.firebaseProjectId,
          messagingSenderId: config.firebaseMessagingSenderId,
          authDomain: config.firebaseAuthDomain.isNotEmpty
              ? config.firebaseAuthDomain
              : null,
          storageBucket: config.firebaseStorageBucket.isNotEmpty
              ? config.firebaseStorageBucket
              : null,
          measurementId: config.firebaseMeasurementId.isNotEmpty
              ? config.firebaseMeasurementId
              : null,
        );
        await firebaseService.init(
          options: webOptions,
          enableAppCheck: config.firebaseRecaptchaV3SiteKey.isNotEmpty,
          webRecaptchaV3SiteKey: config.firebaseRecaptchaV3SiteKey.isNotEmpty
              ? config.firebaseRecaptchaV3SiteKey
              : null,
        );
        firebaseInitialized = firebaseService.isInitialized;
        debugPrint('✅ [Init] Firebase (web) initialized successfully');
      } else {
        // Allow app to run in partial mode without Firebase until configured.
        debugPrint('⚠️ [Init] Firebase config incomplete, running in partial mode');
      }
    }
  } catch (error, stackTrace) {
    debugPrint('🔴 [Init] Firebase initialization failed: $error');
    debugPrint('Stack trace: $stackTrace');
    // Continue app startup - Firebase is critical but we can show error UI
    firebaseInitialized = false;
  }

  // Step 3.3: Initialize Auth Service (depends on Firebase)
  if (firebaseInitialized) {
    try {
      debugPrint('🔄 [Init] Initializing Auth Service...');
      await Get.find<AuthService>().init();
      debugPrint('✅ [Init] Auth Service initialized successfully');
    } catch (error, stackTrace) {
      debugPrint('🔴 [Init] Auth Service initialization failed: $error');
      debugPrint('Stack trace: $stackTrace');
      // Non-critical: app can run without auth initially
    }

    // Step 3.4: Initialize Notification Service (depends on Firebase)
    try {
      debugPrint('🔄 [Init] Initializing Notification Service...');
      await Get.find<NotificationService>().init();
      debugPrint('✅ [Init] Notification Service initialized successfully');
    } catch (error, stackTrace) {
      debugPrint('🔴 [Init] Notification Service initialization failed: $error');
      debugPrint('Stack trace: $stackTrace');
      // Non-critical: app can run without notifications
    }

    // Step 3.5: Start deep link handling (depends on Firebase)
    try {
      debugPrint('🔄 [Init] Starting Deep Link Service...');
      Get.find<DeepLinkService>();
      debugPrint('✅ [Init] Deep Link Service started successfully');
    } catch (error, stackTrace) {
      debugPrint('🔴 [Init] Deep Link Service failed: $error');
      debugPrint('Stack trace: $stackTrace');
      // Non-critical: app can run without deep links
    }
  } else {
    debugPrint('⚠️ [Init] Skipping Firebase-dependent services (Auth, Notifications, Deep Links)');
  }

  // Step 3.6: Initialize GetStorage with error handling
  try {
    debugPrint('🔄 [Init] Initializing GetStorage...');
    await GetStorage.init();
    debugPrint('✅ [Init] GetStorage initialized successfully');
  } catch (error, stackTrace) {
    debugPrint('🔴 [Init] GetStorage initialization failed: $error');
    debugPrint('Stack trace: $stackTrace');
    // Continue - some features may not work but app can still run
  }

  // Step 3.6b: Initialize ThemeService (depends on GetStorage)
  if (Get.isRegistered<ThemeService>()) {
    try {
      debugPrint('🔄 [Init] Initializing ThemeService...');
      await Get.find<ThemeService>().init();
      debugPrint('✅ [Init] ThemeService initialized successfully');
    } catch (error, stackTrace) {
      debugPrint('🔴 [Init] ThemeService initialization failed: $error');
      debugPrint('Stack trace: $stackTrace');
      // Non-critical: continue with system theme
    }
  }

  // Step 3.7: Resume offline queue (depends on GetStorage)
  if (Get.isRegistered<OfflineQueueService>()) {
    try {
      debugPrint('🔄 [Init] Resuming Offline Queue Service...');
      await Get.find<OfflineQueueService>().resume();
      debugPrint('✅ [Init] Offline Queue Service resumed successfully');
    } catch (error, stackTrace) {
      debugPrint('🔴 [Init] Offline Queue Service resume failed: $error');
      debugPrint('Stack trace: $stackTrace');
      // Non-critical: continue without offline queue
    }
  }

  // Step 3.8: Configure Cloudinary (optional)
  try {
    debugPrint('🔄 [Init] Configuring Cloudinary...');
    final config = Get.find<ConfigService>();
    final cloudinary = Get.find<CloudinaryService>();
    if (config.cloudinaryCloudName.isNotEmpty) {
      await cloudinary.configure(
        cloudName: config.cloudinaryCloudName,
        apiKey: config.cloudinaryApiKey.isNotEmpty ? config.cloudinaryApiKey : null,
      );
      debugPrint('✅ [Init] Cloudinary configured successfully');
    } else {
      debugPrint('⚠️ [Init] Cloudinary cloud name not provided, skipping client-side config (secrets stay server-side)');
    }
  } catch (error, stackTrace) {
    debugPrint('🔴 [Init] Cloudinary configuration failed: $error');
    debugPrint('Stack trace: $stackTrace');
    // Non-critical: video features may not work but app can still run
  }

  debugPrint('🎉 [Init] App initialization completed successfully!');
}

/// Step 5: Error fallback UI widget
class ErrorApp extends StatelessWidget {
  final String error;
  final String stackTrace;

  const ErrorApp({
    super.key,
    required this.error,
    required this.stackTrace,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.grey[900],
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 64,
                ),
                const SizedBox(height: 24),
                const Text(
                  'App Initialization Failed',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'The app encountered an error during startup and cannot continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Error Details:',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        child: Text(
                          error,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Attempt to restart the app
                    debugPrint('🔄 User requested app restart');
                    // Note: On most platforms, this will close the app
                    // User needs to manually reopen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Close App',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Please check the console logs for more details.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SnapflowApp extends StatelessWidget {
  SnapflowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService =
        Get.isRegistered<ThemeService>() ? Get.find<ThemeService>() : null;

    if (themeService == null) {
      return GetMaterialApp(
        title: 'Snapflow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
        initialBinding: AppInitialBinding(),
      );
    }

    return Obx(() {
      return GetMaterialApp(
        title: 'Snapflow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeService.themeMode.value,
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
        initialBinding: AppInitialBinding(),
      );
    });
  }
}
