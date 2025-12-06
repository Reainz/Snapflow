import 'package:get/get.dart';

import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import '../services/config_service.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/error_service.dart';
import '../services/deep_link_service.dart';
import '../services/connectivity_service.dart';
import '../services/update_service.dart';
import '../services/offline_queue_service.dart';
import '../services/video_feed_cache_service.dart';
import '../services/social_service.dart';
import '../services/analytics_service.dart';
import '../services/theme_service.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../modules/notifications/controllers/notifications_controller.dart';

class AppInitialBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ConfigService>()) {
      Get.put<ConfigService>(ConfigService(), permanent: true);
    }
    if (!Get.isRegistered<FirebaseService>()) {
      Get.put<FirebaseService>(FirebaseService(), permanent: true);
    }
    if (!Get.isRegistered<CloudinaryService>()) {
      final service = CloudinaryService();
      Get.put<CloudinaryService>(service, permanent: true);
      // Configure from ConfigService dart-define values when available
      final config = Get.find<ConfigService>();
      final cloudName = config.cloudinaryCloudName;
      final apiKey = config.cloudinaryApiKey;
      if (cloudName.isNotEmpty) {
        service.configure(
          cloudName: cloudName,
          apiKey: apiKey.isNotEmpty ? apiKey : null,
        );
      }
    }
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<NotificationService>()) {
      Get.put<NotificationService>(NotificationService(), permanent: true);
    }
    if (!Get.isRegistered<ErrorService>()) {
      Get.put<ErrorService>(ErrorService(), permanent: true);
    }
    if (!Get.isRegistered<AnalyticsService>()) {
      Get.put<AnalyticsService>(AnalyticsService(), permanent: true);
    }
    if (!Get.isRegistered<ThemeService>()) {
      Get.put<ThemeService>(ThemeService(), permanent: true);
    }
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
    if (!Get.isRegistered<UpdateService>()) {
      Get.put<UpdateService>(UpdateService(), permanent: true);
    }
    if (!Get.isRegistered<OfflineQueueService>()) {
      Get.put<OfflineQueueService>(OfflineQueueService(), permanent: true);
    }

    // Register VideoFeedCacheService before VideoRepository
    if (!Get.isRegistered<VideoFeedCacheService>()) {
      Get.put<VideoFeedCacheService>(VideoFeedCacheService(), permanent: true);
    }

    // Repositories
    if (!Get.isRegistered<UserRepository>()) {
      Get.put<UserRepository>(UserRepository(), permanent: true);
    }
    if (!Get.isRegistered<VideoRepository>()) {
      Get.put<VideoRepository>(VideoRepository(), permanent: true);
    }
    if (!Get.isRegistered<NotificationRepository>()) {
      Get.put<NotificationRepository>(
        NotificationRepository(),
        permanent: true,
      );
    }

    // Register SocialService for centralized social actions (like, follow, share, bookmark)
    if (!Get.isRegistered<SocialService>()) {
      Get.put<SocialService>(SocialService(), permanent: true);
    }

    // Make NotificationsController globally available so unread badge updates even
    // before visiting the notifications screen.
    if (!Get.isRegistered<NotificationsController>()) {
      Get.put<NotificationsController>(NotificationsController(), permanent: true);
    }

    // Initialize deep link handling late to avoid early navigation before UI
    if (!Get.isRegistered<DeepLinkService>()) {
      Get.put<DeepLinkService>(DeepLinkService(), permanent: true);
    }
  }
}
