import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/config_service.dart';
import '../../../core/services/error_service.dart';
import '../../../core/services/social_service.dart';
import '../../../core/services/video_feed_cache_service.dart';
// Removed direct offline queuing from controller; repositories handle offline queuing
import '../../../data/models/user_model.dart';
import '../../../data/models/video_model.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/video_repository.dart';
import '../../../routes/app_routes.dart';
import '../../followers_feed/controllers/followers_feed_controller.dart';

enum FeedType { public, followers }

class VideoFeedController extends GetxController {
  VideoFeedController({
    VideoRepository? videoRepository,
    ErrorService? errorService,
    UserRepository? userRepository,
    AuthService? authService,
    SocialService? socialService,
    VideoFeedCacheService? cacheService,
    ConnectivityService? connectivityService,
    AnalyticsService? analyticsService,
    this.feedType = FeedType.public,
  })  : _videoRepository = videoRepository ?? Get.find<VideoRepository>(),
        _errorService = errorService ?? Get.find<ErrorService>(),
      _userRepository = userRepository ??
        (Get.isRegistered<UserRepository>() ? Get.find<UserRepository>() : null),
        _authService = authService ?? Get.find<AuthService>(),
        _socialService = socialService ?? Get.find<SocialService>(),
        _cacheService = cacheService ?? Get.find<VideoFeedCacheService>(),
        _connectivityService = connectivityService ?? Get.find<ConnectivityService>(),
        _analyticsService = analyticsService ?? Get.find<AnalyticsService>();

  static const int _pageSize = 20;
  static const int _topStreamLimit = 50;

  final VideoRepository _videoRepository;
  final ErrorService _errorService;
  final UserRepository? _userRepository;
  final AuthService _authService;
  final SocialService _socialService;
  final VideoFeedCacheService _cacheService;
  final ConnectivityService _connectivityService;
  final AnalyticsService _analyticsService;
  final FirebaseAnalytics _firebaseAnalytics = FirebaseAnalytics.instance;
  final FeedType feedType;
  // Offline queueing is centralized in repositories.

  final videos = <VideoModel>[].obs;
  final currentIndex = 0.obs;
  final isLoading = false.obs;
  final isRefreshing = false.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;
  bool get isFollowersFeed => feedType == FeedType.followers;
  
  // Cache vs Network loading indicator (for Phase 4.3)
  final isLoadingFromCache = false.obs;

  // UI chrome state - hide app chrome for immersive viewing
  final isFullScreenMode = false.obs;

  // Live social state keyed by videoId
  final likesCountByVideo = <String, int>{}.obs;
  final isLikedByVideo = <String, bool>{}.obs;
  final commentsCountByVideo = <String, int>{}.obs;
  final isSavedByVideo = <String, bool>{}.obs;
  
  // Follow status keyed by userId (creator)
  final isFollowingByUser = <String, bool>{}.obs;
  
  // Caption state - global toggle for all videos
  final showCaptions = false.obs;
  
  // Connectivity state - reactive online/offline indicator
  final isOnline = true.obs;
  final isAuthenticated = true.obs;
  final hasFollowedCreators = true.obs;

  // Watch time tracking - map videoId to start timestamp
  final _videoWatchStartTimes = <String, DateTime>{};
  final _videoWatchDurations = <String, int>{}; // Total watch duration in seconds per video
  
  // Static set to track viewed videos across controller instances
  // This prevents view count inflation when navigating back and forth
  // Using static so it persists for the entire app session
  static final _viewCountedVideoIds = <String>{};

  final _videoSubscriptions = <String, List<StreamSubscription>>{};
  StreamSubscription<List<VideoModel>>? _topFeedSub;
  StreamSubscription<bool>? _connectivitySub;
  Worker? _urlRefreshWorker;

  late final PageController pageController;
  final _creatorCache = <String, UserModel>{};
  final _creatorErrorLogged = <String>{};
  final _likeOperationsInFlight = <String>{};
  final _signedUrlFetchedAt = <String, DateTime>{};
  final _signingInFlight = <String>{};
  // Track URL signing errors for visibility and retry
  final videoUrlSigningErrors = <String, String>{}.obs; // videoId -> error message
  List<String>? _cachedFollowingIds;

  Object? _lastCursor;
  DateTime? _lastLoadMoreRequestedAt;
  String? _initialVideoId;
  bool _pendingInitialJump = false;

  @override
  void onInit() {
    super.onInit();
    pageController = PageController();
    
    // Subscribe to connectivity changes
    isOnline.value = _connectivityService.isOnline.value;
    _connectivitySub = _connectivityService.isOnline.listen((online) {
      isOnline.value = online;
      if (online) {
        Get.log('[VideoFeedController] Back online - refreshing feed');
        // Optionally refresh feed when coming back online
        // refreshFeed();
      } else {
        Get.log('[VideoFeedController] Went offline - using cached data');
      }
    });
    
    // Log cache stats on initialization
    final cacheStats = _cacheService.getStats();
    Get.log('[VideoFeedController] Cache initialized: ${cacheStats.size} videos, ${(cacheStats.hitRate * 100).toStringAsFixed(1)}% hit rate');
    
    // Accept an optional initialVideoId route argument to start on a specific video
    final args = Get.arguments;
    if (args is Map && args['initialVideoId'] is String) {
      _initialVideoId = (args['initialVideoId'] as String).trim();
      if (_initialVideoId != null && _initialVideoId!.isNotEmpty) {
        _pendingInitialJump = true;
      }
    }

    // Start periodic URL refresh check (every 10 minutes) scoped to visible videos
    _urlRefreshWorker = interval(
      videos,
      (_) => _refreshExpiringUrlsForVisible(),
      time: const Duration(minutes: 10),
    );
    // Moved loadInitialFeed() and _subscribeTopFeed() to onReady() to ensure Firebase Auth is fully initialized
    // This prevents permission-denied errors from Firestore subscriptions that require authentication
  }

  @override
  void onReady() {
    super.onReady();
    // Load feed and subscribe after widget is ready and auth is initialized
    loadInitialFeed();
    _subscribeTopFeed();
  }

  @override
  void onClose() {
    // Log watch time for current video before closing
    _logWatchTimeForPreviousVideo();
    
    _topFeedSub?.cancel();
    _connectivitySub?.cancel();
    for (final subs in _videoSubscriptions.values) {
      for (final s in subs) {
        s.cancel();
      }
    }
    _videoSubscriptions.clear();
    _urlRefreshWorker?.dispose();
    pageController.dispose();
    super.onClose();
  }

  Future<void> loadInitialFeed() async {
    await _loadFeed(reset: true);
    
    // Start tracking watch time for the first video after initial load
    if (videos.isNotEmpty) {
      _startWatchTimeTracking(0);
    }
  }

  Future<void> refreshFeed() async {
    Get.log('[VideoFeedController] Refreshing feed - preserving cache');
    // Only prune expired entries to keep warm cache available
    await _cacheService.pruneExpiredEntries();
    if (isFollowersFeed) {
      _cachedFollowingIds = null;
      final userId = _authService.currentUser.value?.uid;
      if (userId != null) {
        _videoRepository.invalidateFollowingCache(userId);
      }
    }
    await _loadFeed(reset: true, isRefresh: true);
  }

  Future<void> loadMoreVideos() async {
    await _loadFeed();
  }

  Future<void> _loadFeed({bool reset = false, bool isRefresh = false}) async {
    if (reset) {
      if (isLoading.value || isRefreshing.value) return;
      if (!isRefresh) {
        videos.clear();
        isLoading.value = true;
      } else {
        isRefreshing.value = true;
      }
      hasMore.value = true;
      _lastCursor = null;
      if (isFollowersFeed) {
        _cachedFollowingIds = null;
      }
    } else {
      if (!hasMore.value || isLoadingMore.value || isLoading.value) return;
      final now = DateTime.now();
      if (_lastLoadMoreRequestedAt != null &&
          now.difference(_lastLoadMoreRequestedAt!).inMilliseconds < 400) {
        return;
      }
      _lastLoadMoreRequestedAt = now;
      isLoadingMore.value = true;
    }

    try {
      final page = await _fetchFeedPage(reset: reset);

      // Process video URLs to replace private/followers-only videos with signed URLs
      await _processVideoUrls(page.items);

      if (reset) {
        videos.assignAll(page.items);
        currentIndex.value = 0;
        if (videos.isNotEmpty && pageController.hasClients) {
          pageController.jumpToPage(0);
        }
        _attachRealtimeForVisible();
      } else {
        // Append new page, but avoid duplicates if any arrived via the real-time stream
        final existingIds = videos.map((v) => v.id).toSet();
        final toAdd = page.items.where((v) => !existingIds.contains(v.id)).toList();
        
        // Process URLs for new videos before adding
        await _processVideoUrls(toAdd);
        
        videos.addAll(toAdd);
        _attachRealtimeForVisible(start: _lastCursor != null);
      }

      _lastCursor = page.lastCursor ?? page.lastDoc;
      hasMore.value = page.hasMore;

      // After loading, if we have an initialVideoId, try to jump to it
      if (_pendingInitialJump && _initialVideoId != null) {
        final idx = videos.indexWhere((v) => v.id == _initialVideoId);
        if (idx != -1) {
          currentIndex.value = idx;
          if (pageController.hasClients) {
            pageController.jumpToPage(idx);
          }
          _attachRealtimeForVisible();
          _pendingInitialJump = false;
        }
      }
    } catch (e, stackTrace) {
      // Log detailed error information for debugging
      Get.log('[VideoFeedController] Feed load error: $e', isError: true);
      Get.log('[VideoFeedController] Error type: ${e.runtimeType}', isError: true);
      
      _errorService.handleError(
        e,
        context: 'VideoFeedController._loadFeed',
        stackTrace: stackTrace,
      );
    } finally {
      if (reset) {
        if (isRefresh) {
          isRefreshing.value = false;
        } else {
          isLoading.value = false;
        }
      } else {
        isLoadingMore.value = false;
      }
    }
  }

  Future<VideoPage> _fetchFeedPage({required bool reset}) async {
    if (isFollowersFeed) {
      final followerIds = await _ensureFollowingIds();
      if (!isAuthenticated.value) {
        return VideoPage(items: const [], lastDoc: null, lastCursor: null, hasMore: false);
      }
      return _videoRepository.getFollowersOnlyFeedPage(
        limit: _pageSize,
        startAfter: reset ? null : _lastCursor,
        followedUserIds: followerIds,
      );
    }

    // Public feed
    return _videoRepository.getFeedPage(
      limit: _pageSize,
      startAfter: reset ? null : _lastCursor,
    );
  }

  Future<List<String>> _ensureFollowingIds() async {
    if (!isFollowersFeed) return const [];

    final user = _authService.currentUser.value;
    if (user == null) {
      isAuthenticated.value = false;
      hasFollowedCreators.value = false;
      return const [];
    }

    isAuthenticated.value = true;
    // Always fetch fresh following list to avoid stale cache after follow/unfollow on other screens.
    _videoRepository.invalidateFollowingCache(user.uid);
    final ids = await _videoRepository.getFollowingUserIds(user.uid);
    _cachedFollowingIds = ids;
    hasFollowedCreators.value = ids.isNotEmpty;

    // Immediately prune any videos that are no longer from followed creators
    if (isFollowersFeed && ids.isNotEmpty) {
      _pruneUnfollowedVideos(ids);
    }

    return ids;
  }

  Future<Stream<List<VideoModel>>> _buildTopFeedStream() async {
    if (!isFollowersFeed) {
      return _videoRepository.getVideoFeedStream(limit: _topStreamLimit);
    }

    final followerIds = await _ensureFollowingIds();
    if (!isAuthenticated.value || followerIds.isEmpty) {
      return Stream.value(const <VideoModel>[]);
    }
    return _videoRepository.getFollowersOnlyFeedStream(limit: _topStreamLimit);
  }

  void _subscribeTopFeed() {
    _topFeedSub?.cancel();
    
    // Wait for auth state to be determined before subscribing to feed stream
    // This prevents permission-denied errors when Firestore queries run before auth is ready
    FirebaseAuth.instance.authStateChanges().first.then((user) async {
      // Auth state is now known (user can be null if not authenticated)
      // Now it's safe to subscribe to the feed stream
      _topFeedSub = (await _buildTopFeedStream()).listen((latest) async {
        // For followers feed, drop items from owners no longer followed
        List<VideoModel> filteredLatest = latest;
        if (isFollowersFeed && _cachedFollowingIds != null) {
          final allowedOwners = _cachedFollowingIds!.toSet();
          filteredLatest = latest.where((v) => allowedOwners.contains(v.ownerId)).toList();
          _pruneUnfollowedVideos(_cachedFollowingIds!);
        }

        // Ensure private/followers-only items receive signed URLs before merging
        await _processVideoUrls(filteredLatest);

        // Merge incoming latest into current list, keeping order by createdAt (already sorted by query)
        // Strategy: upsert top items; if an item exists deeper in the list, update it and move it to its sorted spot.
        // Rebuild list: latest first, then any remaining existing not in latest in current order
        final latestIds = filteredLatest.map((v) => v.id).toSet();
        final mergedTop = filteredLatest;
        final tail = videos.where((v) => !latestIds.contains(v.id)).toList();
        videos.assignAll([...mergedTop, ...tail]);
        _attachRealtimeForVisible();
      }, onError: (e, st) {
        // Silently ignore permission-denied errors - these occur when unfollowing
        // and the stream tries to access videos we no longer have permission to view
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('permission-denied') || errorMsg.contains('insufficient permissions')) {
          if (LogConfig.verbose) {
            Get.log('[VideoFeedController] Permission error in feed stream (expected after unfollow): $e');
          }
          return;
        }
        _errorService.handleError(e, context: 'VideoFeedController._subscribeTopFeed', stackTrace: st);
      });
    }).catchError((e, st) async {
      // If auth state check fails, still try to subscribe (might work if rules allow unauthenticated)
      Get.log('[VideoFeedController] Auth state check failed, attempting feed subscription anyway: $e', isError: true);
      _topFeedSub = (await _buildTopFeedStream()).listen((latest) async {
        await _processVideoUrls(latest);

        final latestIds = latest.map((v) => v.id).toSet();
        final mergedTop = latest;
        final tail = videos.where((v) => !latestIds.contains(v.id)).toList();
        videos.assignAll([...mergedTop, ...tail]);
        _attachRealtimeForVisible();
      }, onError: (e, st) {
        // Silently ignore permission-denied errors
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('permission-denied') || errorMsg.contains('insufficient permissions')) {
          if (LogConfig.verbose) {
            Get.log('[VideoFeedController] Permission error in feed stream (expected after unfollow): $e');
          }
          return;
        }
        _errorService.handleError(e, context: 'VideoFeedController._subscribeTopFeed', stackTrace: st);
      });
    });
  }

  // Optional: allow optimistic insertion from upload flow; when server doc arrives it will be de-duped by id
  void insertOptimistic(VideoModel video) {
    if (videos.any((v) => v.id == video.id)) return;
    videos.insert(0, video);
    currentIndex.value = 0;
    if (pageController.hasClients) {
      pageController.jumpToPage(0);
    }
    _attachRealtimeForVisible();
  }

  void onPageChanged(int index) {
    // Log watch event for the previous video before switching
    _logWatchTimeForPreviousVideo();
    
    currentIndex.value = index;

    // Refresh signed URL for the active video if needed (avoids expired tokens)
    if (index >= 0 && index < videos.length) {
      refreshSignedUrlIfNeeded(videos[index].id);
    }
    
    // Start tracking watch time for the new video
    _startWatchTimeTracking(index);
    
    if (hasMore.value && index >= videos.length - 3) {
      loadMoreVideos();
    }
    _attachRealtimeForVisible();
    _preloadNextVideos();
  }

  /// Start tracking watch time for the video at the given index.
  void _startWatchTimeTracking(int index) {
    if (index < 0 || index >= videos.length) return;
    
    final videoId = videos[index].id;
    _videoWatchStartTimes[videoId] = DateTime.now();
    
    Get.log('[VideoFeedController] Started watch time tracking for video: $videoId');
  }

  /// Log watch time event for the previously viewed video.
  /// Also increments view count if watched for at least 3 seconds (prevents rapid scrolling inflation).
  void _logWatchTimeForPreviousVideo() {
    final prevIndex = currentIndex.value;
    if (prevIndex < 0 || prevIndex >= videos.length) return;
    
    final video = videos[prevIndex];
    final videoId = video.id;
    
    // Calculate watch duration if we have a start time
    if (_videoWatchStartTimes.containsKey(videoId)) {
      final startTime = _videoWatchStartTimes[videoId]!;
      final watchDurationSeconds = DateTime.now().difference(startTime).inSeconds;
      
      // Accumulate total watch duration for this video
      _videoWatchDurations[videoId] = 
          (_videoWatchDurations[videoId] ?? 0) + watchDurationSeconds;
      
      final totalWatchDuration = _videoWatchDurations[videoId]!;
      
      // Increment view count if watched for at least 3 seconds and not already counted
      // This prevents view count inflation from rapid scrolling
      if (totalWatchDuration >= 3 && !_viewCountedVideoIds.contains(videoId)) {
        _viewCountedVideoIds.add(videoId);
        _videoRepository.incrementViewCount(videoId);
        Get.log('[VideoFeedController] Incremented view count for video: $videoId');
      }
      
      // Determine if video was "completed" (watched >= 80% of duration)
      final videoDuration = video.duration;
      final completed = videoDuration > 0 && totalWatchDuration >= (videoDuration * 0.8);
      
      // Log event to analytics service
      _analyticsService.logVideoWatchEvent(
        videoId: videoId,
        watchDurationSeconds: totalWatchDuration,
        completed: completed,
      );
      
      Get.log('[VideoFeedController] Logged watch event: videoId=$videoId, duration=${totalWatchDuration}s, completed=$completed');
      
      // Clear tracking for this video
      _videoWatchStartTimes.remove(videoId);
      _videoWatchDurations.remove(videoId);
    }
  }

  /// Preloads thumbnails for the next 3-4 videos to improve feed performance.
  /// 
  /// This method uses Flutter's precacheImage to load thumbnails into cache
  /// before they are visible, providing a smoother scrolling experience.
  void _preloadNextVideos() {
    if (Get.context == null) return;
    
    // Preload thumbnails for the next 3 videos after current index
    final endIdx = math.min(currentIndex.value + 4, videos.length);
    for (int i = currentIndex.value + 1; i < endIdx; i++) {
      final video = videos[i];

      if (video.thumbnailUrl.isNotEmpty) {
        try {
          precacheImage(
            CachedNetworkImageProvider(video.thumbnailUrl),
            Get.context!,
          );
        } catch (e) {
          // Silent failure - preloading is not critical
          if (LogConfig.verbose) {
            Get.log('Failed to preload thumbnail for video ${video.id}: $e');
          }
        }
      }

      // Best-effort manifest preload for upcoming videos (guard signed URLs)
      if (video.hlsUrl.isNotEmpty) {
        final normalizedPrivacy = video.privacy?.trim().toLowerCase();
        final isPublic = normalizedPrivacy == 'public';
        final isSignedFollower = (normalizedPrivacy == 'followers-only' || normalizedPrivacy == 'private') &&
            _signedUrlFetchedAt.containsKey(video.id);

        if (isPublic || isSignedFollower) {
          _preloadManifestBestEffort(video.hlsUrl, video.id);
        }
      }
    }
  }

  Future<UserModel?> fetchCreator(String ownerId) async {
    if (ownerId.isEmpty) return null;
    if (_creatorCache.containsKey(ownerId)) {
      return _creatorCache[ownerId];
    }

    final repository = _userRepository;
    if (repository == null) {
      return null;
    }

    try {
      final user = await repository.getUserById(ownerId);
      _creatorCache[ownerId] = user;
      
      // Also fetch follow status for this creator
      _fetchFollowStatus(ownerId);
      
      return user;
    } catch (e, stackTrace) {
      final message = e.toString();
      if (LogConfig.verbose && !_creatorErrorLogged.contains(ownerId)) {
        Get.log(
          'Failed to load creator $ownerId: $message',
          isError: true,
        );
        _creatorErrorLogged.add(ownerId);
      }
      // Do not surface a global snackbar for expected not-found cases
      // (e.g., seeded test videos without a corresponding user profile).
      if (!message.contains('User not found')) {
        _errorService.handleError(
          e,
          context: 'VideoFeedController.fetchCreator',
          stackTrace: stackTrace,
        );
      }
      return null;
    }
  }
  
  Future<void> _fetchFollowStatus(String targetUserId) async {
    final user = _authService.currentUser.value;
    if (user == null || targetUserId.isEmpty || user.uid == targetUserId) {
      return;
    }
    
    final repository = _userRepository;
    if (repository == null) {
      return;
    }
    
    try {
      final following = await repository.isFollowing(user.uid, targetUserId);
      isFollowingByUser[targetUserId] = following;
    } catch (e) {
      // Silent failure - follow status is not critical
      if (LogConfig.verbose) {
        Get.log('Failed to fetch follow status for $targetUserId: $e');
      }
    }
  }
  
  Future<void> toggleFollow(String targetUserId) async {
    final user = _authService.currentUser.value;
    if (user == null) {
      Get.snackbar(
        'Sign in required',
        'Create an account or log in to follow users.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    
    if (targetUserId.isEmpty || user.uid == targetUserId) {
      return;
    }
    
    final repository = _userRepository;
    if (repository == null) {
      return;
    }
    
    // Optimistic UI update
    final wasFollowing = isFollowingByUser[targetUserId] ?? false;
    isFollowingByUser[targetUserId] = !wasFollowing;
    
    try {
      // Use SocialService to handle follow + notification
      final following = await _socialService.toggleFollow(
        currentUserId: user.uid,
        targetUserId: targetUserId,
      );

      // Update UI with actual result
      isFollowingByUser[targetUserId] = following;
      await handleFollowingChanged(
        userId: user.uid,
        refreshFeed: true,
        unfollowedUserId: following ? null : targetUserId,
      );
      
      Get.snackbar(
        following ? 'Following' : 'Unfollowed',
        following ? 'You are now following this user' : 'You unfollowed this user',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 1),
      );
    } catch (e, stackTrace) {
      // Revert on error
      isFollowingByUser[targetUserId] = wasFollowing;
      _errorService.handleError(
        e,
        context: 'VideoFeedController.toggleFollow',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> handleFollowingChanged({
    required String userId,
    bool refreshFeed = false,
    String? unfollowedUserId,
  }) async {
    _videoRepository.invalidateFollowingCache(userId);
    _cachedFollowingIds = null;

    if (isFollowersFeed) {
      // First, remove videos from unfollowed user BEFORE resubscribing
      // This prevents permission-denied errors when trying to access
      // followers-only videos from users we no longer follow
      if (unfollowedUserId != null) {
        _removeVideosByOwner(unfollowedUserId);
      }
      
      final ids = await _videoRepository.getFollowingUserIds(userId);
      hasFollowedCreators.value = ids.isNotEmpty;
      _cachedFollowingIds = ids;

      // Prune any remaining videos from users we no longer follow
      _pruneUnfollowedVideos(ids);
      
      // Now it's safe to resubscribe - unfollowed content is already removed
      _topFeedSub?.cancel();
      _subscribeTopFeed();
      
      if (refreshFeed) {
        await _loadFeed(reset: true, isRefresh: true);
      }
      return;
    }

    if (Get.isRegistered<FollowersFeedController>()) {
      try {
        await Get.find<FollowersFeedController>()
            .handleFollowingChanged(userId: userId, refreshFeed: refreshFeed, unfollowedUserId: unfollowedUserId);
      } catch (_) {
        // Ignore if followers controller is not available.
      }
    }
  }

  void openCreatorProfile(VideoModel video) {
    if (video.ownerId.isEmpty) {
      return;
    }
    Get.toNamed(
      Routes.profile,
      arguments: {'userId': video.ownerId},
    );
  }

  void onHashtagTapped(String hashtag) {
    final normalized = hashtag.replaceAll('#', '').trim();
    if (normalized.isEmpty) {
      return;
    }

    if (LogConfig.verbose) {
      Get.log('onHashtagTapped -> #$normalized');
    }

    Get.toNamed(
      Routes.search,
      arguments: {'hashtag': normalized},
    );
  }

  void handleLikeTap(VideoModel video) {
    Get.log('handleLikeTap called for video: ${video.id}');
    _toggleLike(video);
  }

  void openComments(VideoModel video) {
    Get.log('openComments called for video: ${video.id}');
    Get.toNamed(
      Routes.comments,
      arguments: {
        'videoId': video.id,
        'ownerId': video.ownerId,
        'video': video,
      },
    );
  }

  Future<void> shareVideo(VideoModel video) async {
    try {
      Get.log('shareVideo called for video: ${video.id}');
      if (LogConfig.verbose) Get.log('shareVideo -> ${video.id}');
      
      final user = _authService.currentUser.value;
      if (user == null) {
        Get.snackbar(
          'Sign in required',
          'Create an account or log in to share videos.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      
      // Use SocialService to handle sharing + notification
      final result = await _socialService.shareVideo(
        video: video,
        userId: user.uid,
      );
      
      // Show feedback based on share result
      if (result.status == ShareResultStatus.success) {
        // Increment sharesCount in Firestore
        try {
          await FirebaseFirestore.instance
              .collection('videos')
              .doc(video.id)
              .update({
            'sharesCount': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          Get.log('sharesCount incremented for video: ${video.id}');
        } catch (e) {
          // Silent failure - share already succeeded, counter increment is not critical
          Get.log('Failed to increment sharesCount: $e');
        }
        
        Get.snackbar(
          'Shared',
          'Video shared successfully!',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else if (result.status == ShareResultStatus.dismissed) {
        // User dismissed share dialog - no feedback needed
        Get.log('Share dismissed by user');
      }
    } catch (e) {
      Get.log('Error sharing video: $e');
      Get.snackbar(
        'Share Failed',
        'Unable to share video. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Flags a video as inappropriate for admin moderation
  /// Shows confirmation dialog before flagging
  /// Prevents users from flagging their own videos
  /// Rate limits to max 10 flags per 24 hours per user
  Future<void> flagVideo(VideoModel video) async {
    try {
      Get.log('flagVideo called for video: ${video.id}');
      if (LogConfig.verbose) Get.log('flagVideo -> ${video.id}');
      
      final user = _authService.currentUser.value;
      if (user == null) {
        Get.snackbar(
          'Sign in required',
          'Create an account or log in to flag videos.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      
      // Prevent users from flagging their own videos
      if (video.ownerId == user.uid) {
        Get.snackbar(
          'Cannot Flag Own Video',
          'You cannot flag your own videos.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        Get.log('User attempted to flag their own video: ${video.id}');
        return;
      }
      
      // Show confirmation dialog
      final confirmed = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Flag Video'),
          content: const Text(
            'Are you sure you want to flag this video as inappropriate? '
            'Our moderation team will review it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Flag'),
            ),
          ],
        ),
        barrierDismissible: false,
      );
      
      // If user cancelled, return
      if (confirmed != true) {
        Get.log('Flag cancelled by user');
        return;
      }
      
      // Flag the video via repository (server-side rate limiting)
      await _videoRepository.flagVideo(video.id);
      
      // Show success message
      Get.snackbar(
        'Video Flagged',
        'Thank you. Our team will review this video.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      
      Get.log('Video ${video.id} flagged successfully');
    } on FirebaseException catch (error) {
      Get.log('Firebase error flagging video: ${error.code} - ${error.message}', isError: true);
      
      // Check for rate limit error
      if (error.code == 'failed-precondition' && 
          error.message?.contains('Flag limit reached') == true) {
        // Parse retry time from error message
        final retryMatch = RegExp(r'(\d+)\s+(minute|hour)s?').firstMatch(error.message ?? '');
        String retryMessage = 'Please try again later.';
        if (retryMatch != null) {
          final time = retryMatch.group(1);
          final unit = retryMatch.group(2);
          retryMessage = 'Try again in $time $unit${int.parse(time!) > 1 ? 's' : ''}.';
        }
        
        Get.snackbar(
          'Flag Limit Reached',
          'You have reached the maximum number of flags. $retryMessage',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          icon: const Icon(Icons.timer, color: Colors.white),
          duration: const Duration(seconds: 5),
        );
      } else {
        Get.snackbar(
          'Flag Failed',
          'Unable to flag video. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.log('Error flagging video: $e', isError: true);
      Get.snackbar(
        'Flag Failed',
        'Unable to flag video. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void toggleBookmark(VideoModel video) {
    Get.log('toggleBookmark called for video: ${video.id}');
    if (LogConfig.verbose) Get.log('toggleBookmark -> ${video.id}');
    final user = _authService.currentUser.value;
    if (user == null) {
      Get.snackbar(
        'Sign in required',
        'Create an account or log in to save videos.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Optimistic UI update
    final wasSaved = isSavedByVideo[video.id] ?? false;
    isSavedByVideo[video.id] = !wasSaved;
    Get.log('toggleBookmark: optimistic update to ${!wasSaved}');

    // Use SocialService to handle bookmark
    _socialService
        .toggleBookmark(videoId: video.id, userId: user.uid)
        .then((saved) {
          Get.log('toggleBookmark: server response saved=$saved');
          isSavedByVideo[video.id] = saved;
          Get.snackbar(
            saved ? 'Saved' : 'Removed',
            saved ? 'Video saved to your collection' : 'Video removed from saved',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 1),
          );
        })
        .catchError((e, st) {
          Get.log('toggleBookmark error: $e', isError: true);
          // Revert on error
          isSavedByVideo[video.id] = wasSaved;
          _errorService.handleError(e, context: 'toggleBookmark', stackTrace: st);
        });
  }

  void toggleCaptions() {
    showCaptions.value = !showCaptions.value;
    Get.snackbar(
      showCaptions.value ? 'Captions On' : 'Captions Off',
      showCaptions.value ? 'Captions enabled' : 'Captions disabled',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
    );
  }

  void toggleFullScreenMode() {
    isFullScreenMode.value = !isFullScreenMode.value;
    Get.snackbar(
      isFullScreenMode.value ? 'Immersive On' : 'Immersive Off',
      isFullScreenMode.value
          ? 'App chrome hidden for full-screen viewing'
          : 'Standard controls restored',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
    );
  }

  void setFullScreenMode(bool enabled) {
    if (isFullScreenMode.value == enabled) return;
    isFullScreenMode.value = enabled;
  }

  Future<void> _toggleLike(VideoModel video) async {
    if (video.id.isEmpty) {
      return;
    }

    final user = _authService.currentUser.value;
    if (user == null) {
      Get.snackbar(
        'Sign in required',
        'Create an account or log in to like videos.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (_likeOperationsInFlight.contains(video.id)) {
      return;
    }

    final index = videos.indexWhere((element) => element.id == video.id);
    if (index == -1) {
      return;
    }

    final previousVideo = videos[index];
    final optimisticLikes = math.max(
      0,
      previousVideo.likesCount + (previousVideo.isLiked ? -1 : 1),
    );
    final optimisticVideo = previousVideo.copyWith(
      isLiked: !previousVideo.isLiked,
      likesCount: optimisticLikes,
    );

    videos[index] = optimisticVideo;
    _likeOperationsInFlight.add(video.id);

    Future<void> exec() async {
      // Use SocialService to handle like + notification
      final result = await _socialService.toggleLike(
        videoId: video.id,
        userId: user.uid,
        video: video,
      );

      final updatedIndex = videos.indexWhere((element) => element.id == video.id);
      if (updatedIndex == -1) {
        return;
      }

      videos[updatedIndex] = videos[updatedIndex].copyWith(
        isLiked: result.isLiked,
        likesCount: result.likesCount,
      );
      // Also update live maps so other UI (action bar) reflects instantly
      isLikedByVideo[video.id] = result.isLiked;
      likesCountByVideo[video.id] = result.likesCount;
      
      // User feedback
      if (result.isLiked) {
        Get.snackbar(
          'Liked',
          'Added to your liked videos',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 1),
        );
      }
    }

    try {
      await exec();
    } catch (e, stackTrace) {
      final fallbackIndex = videos.indexWhere((element) => element.id == video.id);
      if (fallbackIndex != -1) {
        videos[fallbackIndex] = previousVideo;
      }
      _errorService.handleError(
        e,
        context: 'VideoFeedController._toggleLike',
        stackTrace: stackTrace,
      );
    } finally {
      _likeOperationsInFlight.remove(video.id);
    }
  }

  void _attachRealtimeForVisible({bool start = false}) {
    // Subscribe to a small window around currentIndex
    final startIdx = (currentIndex.value - 1).clamp(0, videos.length);
    final endIdx = (currentIndex.value + 2).clamp(0, videos.length);
    final targetIds = videos.sublist(startIdx, endIdx).map((v) => v.id).toSet();

    // Unsubscribe from videos that are far away
    for (final entry in _videoSubscriptions.entries.toList()) {
      if (!targetIds.contains(entry.key)) {
        for (final sub in entry.value) {
          sub.cancel();
        }
        _videoSubscriptions.remove(entry.key);
      }
    }

    final uid = _authService.currentUser.value?.uid;
    for (final vid in targetIds) {
      if (_videoSubscriptions.containsKey(vid)) continue;
      final subs = <StreamSubscription>[];
      
      // Add error handlers to prevent permission-denied errors from showing
      // when a video is removed due to unfollow but stream is still active
      void onStreamError(dynamic e) {
        // Silently ignore permission errors - video will be removed from feed
        if (LogConfig.verbose) {
          Get.log('[VideoFeedController] Stream error for $vid: $e');
        }
      }
      
      subs.add(
        _videoRepository.likesCountStream(vid).listen(
          (c) => likesCountByVideo[vid] = c,
          onError: onStreamError,
        ),
      );
      subs.add(
        _videoRepository.commentsCountStream(vid).listen(
          (c) => commentsCountByVideo[vid] = c,
          onError: onStreamError,
        ),
      );
      if (uid != null) {
        subs.add(
          _videoRepository.isLikedStream(videoId: vid, userId: uid).listen(
            (v) => isLikedByVideo[vid] = v,
            onError: onStreamError,
          ),
        );
        subs.add(
          _videoRepository.isSavedStream(videoId: vid, userId: uid).listen(
            (v) => isSavedByVideo[vid] = v,
            onError: onStreamError,
          ),
        );
      }
      _videoSubscriptions[vid] = subs;
    }
  }

  /// Removes a video from the feed list after deletion
  /// Called when a video is deleted from profile or other screens
  void removeVideoFromFeed(String videoId) {
    final index = videos.indexWhere((video) => video.id == videoId);
    if (index != -1) {
      videos.removeAt(index);
      
      // Cancel subscriptions for this video
      final subs = _videoSubscriptions.remove(videoId);
      if (subs != null) {
        for (final s in subs) {
          s.cancel();
        }
      }
      
      // Clean up cached states
      likesCountByVideo.remove(videoId);
      isLikedByVideo.remove(videoId);
      commentsCountByVideo.remove(videoId);
      isSavedByVideo.remove(videoId);
      videoUrlSigningErrors.remove(videoId);
      
      Get.log('[VideoFeedController] Removed video $videoId from feed');
    }
  }

  /// Processes videos to replace HLS URLs with signed URLs for private/followers-only videos.
  /// 
  /// This method reads the privacy field already available on each VideoModel and requests
  /// signed URLs from the Cloud Function when needed. Public videos keep their original HLS URLs.
  /// Private videos require signed URLs for time-limited access control.
  Future<void> _processVideoUrls(List<VideoModel> videoList) async {
    final currentUserId = _authService.currentUser.value?.uid;
    if (currentUserId == null) return;

    for (var i = 0; i < videoList.length; i++) {
      final video = videoList[i];

      // Skip if no HLS URL yet
      if (video.hlsUrl.isEmpty) continue;

      try {
        // Use privacy field provided on the model to avoid extra Firestore lookups
        final normalizedPrivacy = video.privacy?.trim().toLowerCase();

        // Skip signed URL if privacy is null (document doesn't exist or field missing)
        if (normalizedPrivacy == null || normalizedPrivacy.isEmpty) {
          Get.log('Video ${video.id} has no privacy field, using direct URL');
          continue;
        }

        // Check if URL is from Cloudinary (Flow B)
        final isCloudinaryUrl = video.hlsUrl.contains('res.cloudinary.com') ||
                                 video.hlsUrl.contains('cloudinary.com');
        final isFirebaseStorageUrl = _isFirebaseStorageUrl(video.hlsUrl);
        final isOurCloudinaryAsset = _isOurCloudinaryUrl(video.hlsUrl);

        // For non-Cloudinary URLs (legacy Flow A or public test URLs), skip signing for public videos
        if (!isCloudinaryUrl && normalizedPrivacy == 'public') {
          Get.log('Video ${video.id} uses non-Cloudinary public URL, skipping signing');
          videoUrlSigningErrors.remove(video.id);
          continue;
        }

        // Request signed URLs for private or followers-only videos (Cloudinary or legacy storage)
        if (normalizedPrivacy == 'private' || normalizedPrivacy == 'followers-only') {
          // If the URL host is neither Cloudinary nor Firebase Storage, we cannot sign it. Use as-is.
          if (!isCloudinaryUrl && !isFirebaseStorageUrl) {
            Get.log('Video ${video.id} uses unsupported host for signing; using original URL');
            videoUrlSigningErrors.remove(video.id);
            continue;
          }

          // Skip signing for Cloudinary assets that are not in our cloud (e.g., demo/sample hosts)
          if (isCloudinaryUrl && !isOurCloudinaryAsset) {
            Get.log('Video ${video.id} uses external Cloudinary host; skipping signing and keeping URL as-is');
            videoUrlSigningErrors.remove(video.id);
            continue;
          }

          if (!isCloudinaryUrl && isFirebaseStorageUrl) {
            Get.log('Video ${video.id} uses legacy storage URL, requesting signed URL via fallback');
          }
          final signedUrl = await _videoRepository.getSignedVideoUrl(video.id);

          // Replace HLS URL with signed URL using copyWith
          videoList[i] = video.copyWith(hlsUrl: signedUrl);
          _signedUrlFetchedAt[video.id] = DateTime.now();
          videoUrlSigningErrors.remove(video.id);
        }
      } catch (e, stackTrace) {
        // Log error but don't fail the entire feed load; keep video visible with error marker
        Get.log(
          'Failed to process URL for video ${video.id}: $e',
          isError: true,
        );
        if (LogConfig.verbose) {
          debugPrint('Stack trace: $stackTrace');
        }
        videoUrlSigningErrors[video.id] = _getUserFriendlyErrorMessage(e);
        unawaited(_firebaseAnalytics.logEvent(
          name: 'video_url_signing_failed',
          parameters: {
            'video_id': video.id,
            'error_type': e.runtimeType.toString(),
            'error_message': e.toString().substring(0, math.min(100, e.toString().length)),
          },
        ));
      }
    }

    if (videoUrlSigningErrors.isNotEmpty) {
      Get.log(
        'URL signing failed for ${videoUrlSigningErrors.length} videos - errors tracked for retry',
      );
    }
  }

  /// Refreshes the signed URL for a specific video when privacy requires it.
  /// Uses a short TTL check to avoid spamming the Cloud Function.
  Future<VideoModel?> refreshSignedUrlIfNeeded(String videoId, {bool force = false}) async {
    final idx = videos.indexWhere((v) => v.id == videoId);
    if (idx == -1) return null;

    final video = videos[idx];
    final normalizedPrivacy = video.privacy?.trim().toLowerCase();
    final requiresSigning = normalizedPrivacy == 'private' || normalizedPrivacy == 'followers-only';
    if (!requiresSigning) return video;

    final isCloudinaryUrl = video.hlsUrl.contains('res.cloudinary.com') ||
                            video.hlsUrl.contains('cloudinary.com');
    final isFirebaseStorageUrl = _isFirebaseStorageUrl(video.hlsUrl);
    final isOurCloudinaryAsset = _isOurCloudinaryUrl(video.hlsUrl);

    // If this is a private/followers-only video but not hosted in our Cloudinary cloud
    // (e.g., demo/sample host), skip signing and keep the URL as-is.
    if (isCloudinaryUrl && !isOurCloudinaryAsset) {
      videoUrlSigningErrors.remove(video.id);
      return video;
    }

    if (!isCloudinaryUrl && !isFirebaseStorageUrl) {
      // Unsupported host; leave URL as-is to allow demo/test streams to play.
      videoUrlSigningErrors.remove(video.id);
      return video;
    }

    final lastFetched = _signedUrlFetchedAt[videoId];
    if (!force && lastFetched != null && DateTime.now().difference(lastFetched) < const Duration(minutes: 50)) {
      return video;
    }

    if (_signingInFlight.contains(videoId)) return video;
    _signingInFlight.add(videoId);

    try {
      final signedUrl = await _videoRepository.getSignedVideoUrl(videoId);
      final updated = video.copyWith(hlsUrl: signedUrl);
      videos[idx] = updated;
      _signedUrlFetchedAt[videoId] = DateTime.now();
      videoUrlSigningErrors.remove(videoId);
      return updated;
    } catch (e, stackTrace) {
      videoUrlSigningErrors[videoId] = _getUserFriendlyErrorMessage(e);
      _errorService.handleError(
        e,
        context: 'VideoFeedController.refreshSignedUrlIfNeeded',
        stackTrace: stackTrace,
      );
      return video;
    } finally {
      _signingInFlight.remove(videoId);
    }
  }

  /// Refresh expiring signed URLs only for a small window around the visible index.
  Future<void> _refreshExpiringUrlsForVisible() async {
    if (videos.isEmpty || currentIndex.value < 0) return;

    final startIdx = (currentIndex.value - 3).clamp(0, videos.length);
    final endIdx = (currentIndex.value + 4).clamp(0, videos.length);

    for (int i = startIdx; i < endIdx; i++) {
      final video = videos[i];
      final fetchedAt = _signedUrlFetchedAt[video.id];

      if (fetchedAt != null) {
        final age = DateTime.now().difference(fetchedAt);
        if (age > const Duration(minutes: 50)) {
          try {
            await refreshSignedUrlIfNeeded(video.id, force: true);
            Get.log('Proactively refreshed expiring URL for ${video.id}');
          } catch (e) {
            Get.log('Failed to proactively refresh URL for ${video.id}: $e');
          }
        }
      }
    }
  }

  /// Best-effort manifest preload to warm CDN cache without burning signed URLs.
  void _preloadManifestBestEffort(String hlsUrl, String videoId) {
    try {
      final uri = Uri.tryParse(hlsUrl);
      if (uri == null) return;

      http.head(uri).then((response) {
        if (response.statusCode == 200 && LogConfig.verbose) {
          Get.log('Preloaded manifest for video $videoId');
        }
      }).catchError((e) {
        if (LogConfig.verbose) {
          Get.log('Manifest preload failed for $videoId: $e');
        }
      });
    } catch (_) {
      // Best-effort only
    }
  }

  /// Converts technical errors to user-friendly messages
  String _getUserFriendlyErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('failed-precondition')) {
      return 'Video needs migration - contact support';
    } else if (errorStr.contains('timeout') || errorStr.contains('network')) {
      return 'Network error - tap to retry';
    } else if (errorStr.contains('permission') || errorStr.contains('unauthorized')) {
      return 'Access denied - check permissions';
    } else {
      return 'Temporary error - tap to retry';
    }
  }

  bool _isFirebaseStorageUrl(String url) {
    if (url.isEmpty) return false;
    return url.contains('firebasestorage.googleapis.com') ||
        url.contains('storage.googleapis.com') ||
        url.startsWith('gs://');
  }

  bool _isOurCloudinaryUrl(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();

    // Accept both:
    // - configured cloud name (via --dart-define=CLOUDINARY_CLOUD_NAME=...)
    // - legacy fallback used in earlier builds (to avoid breaking existing deployments)
    final cloudNames = <String>{'dfvluekew'};
    try {
      if (Get.isRegistered<ConfigService>()) {
        final configured = Get.find<ConfigService>().cloudinaryCloudName.trim().toLowerCase();
        if (configured.isNotEmpty) cloudNames.add(configured);
      }
    } catch (_) {
      // Ignore; use fallback.
    }

    for (final cloud in cloudNames) {
      if (lower.contains('res.cloudinary.com/$cloud')) return true;
    }
    return false;
  }

  /// Remove videos that no longer belong to followed creators to reflect unfollow immediately.
  void _pruneUnfollowedVideos(List<String> currentFollowIds) {
    if (!isFollowersFeed) return;
    final toRemove = <String>[];
    for (final v in videos) {
      if (!currentFollowIds.contains(v.ownerId)) {
        toRemove.add(v.id);
      }
    }
    if (toRemove.isEmpty) return;
    videos.removeWhere((v) => toRemove.contains(v.id));
    for (final id in toRemove) {
      final subs = _videoSubscriptions.remove(id);
      if (subs == null) continue;
      for (final sub in subs) {
        sub.cancel();
      }
    }
    Get.log('[VideoFeedController] Pruned ${toRemove.length} videos after unfollow');
  }

  /// Remove all videos in feed for a specific creator (used immediately after unfollow).
  void _removeVideosByOwner(String ownerId) {
    if (ownerId.isEmpty) return;
    final toRemove = videos.where((v) => v.ownerId == ownerId).map((v) => v.id).toList();
    if (toRemove.isEmpty) return;
    videos.removeWhere((v) => v.ownerId == ownerId);
    for (final id in toRemove) {
      final subs = _videoSubscriptions.remove(id);
      if (subs == null) continue;
      for (final sub in subs) {
        sub.cancel();
      }
    }
    Get.log('[VideoFeedController] Removed ${toRemove.length} videos for unfollowed owner $ownerId');
  }

  // Rate limiting for social actions is now handled server-side via Cloud Functions and Firestore triggers
}
