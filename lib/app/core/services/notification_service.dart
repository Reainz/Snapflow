import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';
import 'auth_service.dart';

class NotificationService extends GetxService {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  FirebaseFirestore? _firestore; // lazy-init after Firebase is ready
  StreamSubscription? _authSub;

  Future<void> init() async {
    try {
      // Initialize Firestore handle only if Firebase has been initialized
      if (Firebase.apps.isNotEmpty) {
        _firestore = FirebaseFirestore.instance;
      }

      await _messaging.requestPermission();
      // Save/update FCM token for current user if available via AuthService
      final token = await _messaging.getToken();
      await _saveToken(token);

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((t) => _saveToken(t));

      // Foreground message handler (optional UI handling elsewhere)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        Get.log('FCM foreground: ${message.data}');
      });

      // Notification click from terminated/background
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleClick(initialMessage);
      }
      FirebaseMessaging.onMessageOpenedApp.listen(_handleClick);
    } catch (error, stackTrace) {
      Get.log(
        'Notification permission request failed: $error\n$stackTrace',
        isError: true,
      );
    }

    // Re-bind to auth changes so when a user logs in after app start
    // we associate the existing FCM token with their user document.
    try {
      if (Get.isRegistered<AuthService>()) {
        final auth = Get.find<AuthService>();
        _authSub?.cancel();
        _authSub = auth.currentUser.listen((user) async {
          if (user == null) return;
          try {
            final t = await _messaging.getToken();
            await _saveToken(t);
          } catch (e) {
            Get.log('Failed to refresh FCM token on auth change: $e', isError: true);
          }
        });
      }
    } catch (e) {
      Get.log('Failed to bind auth listener for notifications: $e', isError: true);
    }
  }

  Future<String?> getDeviceToken() => _messaging.getToken();

  Future<void> _saveToken(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      // Skip if Firebase isn't initialized yet (e.g., widget tests)
      if (Firebase.apps.isEmpty) return;
      _firestore ??= FirebaseFirestore.instance;
      // Read current userId from AuthService if registered
      String? uid;
      try {
        if (Get.isRegistered<AuthService>()) {
          final auth = Get.find<AuthService>();
          uid = auth.currentUser.value?.uid;
        }
      } catch (_) {}

      if (uid == null || uid.isEmpty) return;
      await _firestore!
          .collection('users')
          .doc(uid)
          .update({'fcmToken': token});
    } catch (e) {
      Get.log('Failed to save FCM token: $e', isError: true);
    }
  }

  void _handleClick(RemoteMessage message) {
    final data = message.data;
    final route = data['route'] as String? ?? '';
    if (route == 'video' && (data['videoId'] as String?)?.isNotEmpty == true) {
      Get.toNamed(Routes.comments, arguments: {
        'videoId': data['videoId'],
      });
    } else if (route == 'comments' && (data['videoId'] as String?)?.isNotEmpty == true) {
      Get.toNamed(Routes.comments, arguments: {
        'videoId': data['videoId'],
      });
    } else if (route == 'profile' && (data['userId'] as String?)?.isNotEmpty == true) {
      Get.toNamed(Routes.profile, arguments: {
        'userId': data['userId'],
      });
    } else {
      // Fallback to notifications screen
      Get.toNamed(Routes.notifications);
    }
  }

  @override
  void onClose() {
    _authSub?.cancel();
    super.onClose();
  }
}
