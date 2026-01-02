import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/video_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/video_repository.dart';
import 'auth_service.dart';
import 'error_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized service for orchestrating social actions (like, follow, share, bookmark).
/// Handles repository calls and notification creation, eliminating code duplication across controllers.
class SocialService extends GetxService {
  // Dependencies - injected via Get.find()
  late final VideoRepository _videoRepository;
  late final UserRepository _userRepository;
  late final NotificationRepository _notificationRepository;
  late final ErrorService _errorService;
  late final AuthService _authService;
  String? _cachedDisplayName;

  @override
  void onInit() {
    super.onInit();
    _videoRepository = Get.find<VideoRepository>();
    _userRepository = Get.find<UserRepository>();
    _notificationRepository = Get.find<NotificationRepository>();
    _errorService = Get.find<ErrorService>();
    _authService = Get.find<AuthService>();
  }

  Future<String?> _getCurrentUserDisplayName(String userId) async {
    if (_cachedDisplayName != null && _cachedDisplayName!.isNotEmpty) {
      return _cachedDisplayName;
    }
    try {
      final user = await _userRepository.getUserById(userId);
      final name = (user.displayName.isNotEmpty
              ? user.displayName
              : user.username)
          .trim();
      _cachedDisplayName = name;
      return name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
  }

  /// Toggle like on a video.
  /// - Calls VideoRepository.toggleLike() for data persistence
  /// - Creates notification for video owner (if liked and not own video)
  /// - Returns ToggleLikeResult for controller to update UI optimistically
  Future<ToggleLikeResult> toggleLike({
    required String videoId,
    required String userId,
    required VideoModel video,
  }) async {
    try {
      // Validate authentication
      if (_authService.currentUser.value?.uid != userId) {
        throw Exception('User authentication mismatch');
      }

      // Call repository to toggle like
      final result = await _videoRepository.toggleLike(
        videoId: videoId,
        userId: userId,
      );

      // Create notification if liked and not own video
      if (result.isLiked && video.ownerId != userId) {
        try {
          final actorName = await _getCurrentUserDisplayName(userId);
          await _notificationRepository.createNotification(
            recipientUserId: video.ownerId,
            type: AppNotificationType.like,
            actorUserId: userId,
            videoId: videoId,
            actorDisplayName: actorName,
            title: 'New Like',
          );
        } catch (e) {
          // Silent failure for notifications - don't block like action
          Get.log('Failed to create like notification: $e');
        }
      }

      return result;
    } catch (e, stackTrace) {
      _errorService.handleError(e, context: 'toggleLike', stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Toggle follow on a user.
  /// - Calls UserRepository.toggleFollow() for data persistence
  /// - Creates notification for target user (if newly following)
  /// - Returns new follow state (true = following, false = unfollowed)
  Future<bool> toggleFollow({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      // Validate authentication
      if (_authService.currentUser.value?.uid != currentUserId) {
        throw Exception('User authentication mismatch');
      }

      // Validate not self-follow
      if (currentUserId == targetUserId) {
        throw Exception('Cannot follow yourself');
      }

      // Check current follow state before toggling
      final followDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId)
          .get();

      final wasFollowing = followDoc.exists;

      // Call repository to toggle follow
      await _userRepository.toggleFollow(currentUserId, targetUserId);

      // Following list cache is used by the Following feed; invalidate after any follow/unfollow.
      _videoRepository.invalidateFollowingCache(currentUserId);

      // If newly following, create notification
      if (!wasFollowing) {
        try {
          final actorName = await _getCurrentUserDisplayName(currentUserId);
          await _notificationRepository.createNotification(
            recipientUserId: targetUserId,
            type: AppNotificationType.follow,
            actorUserId: currentUserId,
            actorDisplayName: actorName,
            title: 'New Follower',
          );
        } catch (e) {
          // Silent failure for notifications - don't block follow action
          Get.log('Failed to create follow notification: $e');
        }
      }

      // Return new follow state (opposite of what it was)
      return !wasFollowing;
    } catch (e, stackTrace) {
      _errorService.handleError(e, context: 'toggleFollow', stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Share a video.
  /// - Uses SharePlus to share video
  /// - Creates notification for video owner (if not own video)
  /// - Returns ShareResult for feedback
  Future<ShareResult> shareVideo({
    required VideoModel video,
    required String userId,
  }) async {
    try {
      // Validate authentication
      if (_authService.currentUser.value?.uid != userId) {
        throw Exception('User authentication mismatch');
      }

      // Share video using SharePlus
      final shareText = '''
${video.title}

${video.description}

Watch now: https://snapflow.app/video/${video.id}
      '''.trim();
      
      final result = await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: 'Check out this video on Snapflow',
        ),
      );

      // Create notification if not own video (only if share was successful)
      if (result.status == ShareResultStatus.success && video.ownerId != userId) {
        try {
          final actorName = await _getCurrentUserDisplayName(userId);
          await _notificationRepository.createNotification(
            recipientUserId: video.ownerId,
            type: AppNotificationType.share,
            actorUserId: userId,
            videoId: video.id,
            actorDisplayName: actorName,
            title: 'Video Shared',
          );
        } catch (e) {
          // Silent failure for notifications - don't block share action
          Get.log('Failed to create share notification: $e');
        }
      }

      return result;
    } catch (e, stackTrace) {
      _errorService.handleError(e, context: 'shareVideo', stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Share a user's profile link.
  Future<ShareResult> shareProfile(UserModel user) async {
    try {
      final current = _authService.currentUser.value;
      if (current == null) {
        throw Exception('User not authenticated');
      }

      final display = user.displayName.isNotEmpty ? user.displayName : user.username;
      final profileUrl = 'https://snapflow.app/@${user.username}';

      final text = '''
Check out $display on Snapflow
$profileUrl
'''.trim();

      return await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: 'Check out this Snapflow profile',
        ),
      );
    } catch (e, stackTrace) {
      _errorService.handleError(e, context: 'shareProfile', stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Toggle bookmark/save on a video.
  /// - Calls VideoRepository.toggleSave() for data persistence
  /// - Returns new saved state (true = saved, false = unsaved)
  /// - No notification needed for bookmarks
  Future<bool> toggleBookmark({
    required String videoId,
    required String userId,
  }) async {
    try {
      // Validate authentication
      if (_authService.currentUser.value?.uid != userId) {
        throw Exception('User authentication mismatch');
      }

      // Call repository to toggle save
      final isSaved = await _videoRepository.toggleSave(
        videoId: videoId,
        userId: userId,
      );

      return isSaved;
    } catch (e, stackTrace) {
      _errorService.handleError(e, context: 'toggleBookmark', stackTrace: stackTrace);
      rethrow;
    }
  }
}
