import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/video_model.dart';
import '../../../data/repositories/video_repository.dart';
import '../../../routes/app_routes.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/social_service.dart';

/// Controller for displaying a filtered video feed (liked, saved, or user videos).
/// Supports vertical swiping through the filtered videos.
class FilteredVideoFeedController extends GetxController {
  final VideoRepository _videoRepository = Get.find<VideoRepository>();
  final SocialService _socialService = Get.find<SocialService>();
  final AuthService _authService = Get.find<AuthService>();

  final videos = <VideoModel>[].obs;
  final currentIndex = 0.obs;
  final isLoading = false.obs;
  final error = ''.obs;
  final filterType = 'liked'.obs; // 'liked', 'saved', or 'user'

  late final PageController pageController;
  
  String? _userId;
  String? _initialVideoId;
  StreamSubscription<List<String>>? _videoIdsSubscription;
  final Map<String, StreamSubscription<VideoModel?>> _videoSubscriptions = {};
  
  // Watch time tracking for view counts
  final _videoWatchStartTimes = <String, DateTime>{};
  final _videoWatchDurations = <String, int>{};
  // Static set shared with VideoFeedController to prevent duplicate view counts
  static final _viewCountedVideoIds = <String>{};
  
  // Pre-loaded videos for search results
  List<VideoModel>? _preloadedVideos;

  @override
  void onInit() {
    super.onInit();
    
    // Get arguments
    final args = Get.arguments;
    if (args is Map) {
      filterType.value = (args['filterType'] as String?) ?? 'liked';
      _initialVideoId = args['initialVideoId'] as String?;
      _userId = args['userId'] as String?;
      
      // Handle pre-loaded videos for search results
      if (args['videos'] is List<VideoModel>) {
        _preloadedVideos = args['videos'] as List<VideoModel>;
      }
    }

    // For search filter type, userId is not required
    if (filterType.value != 'search') {
      // If no userId provided, use current user
      _userId ??= _authService.currentUser.value?.uid;

      if (_userId == null || _userId!.isEmpty) {
        error.value = 'User not found';
        return;
      }
    }

    pageController = PageController();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    try {
      isLoading.value = true;
      error.value = '';

      // Subscribe to video IDs or videos stream based on filter type
      if (filterType.value == 'search' && _preloadedVideos != null) {
        // Use pre-loaded videos from search results
        await _loadSearchVideos();
      } else if (filterType.value == 'liked') {
        _videoIdsSubscription = _videoRepository
            .likedVideoIdsStream(_userId!)
            .listen(_handleVideoIds);
      } else if (filterType.value == 'saved') {
        _videoIdsSubscription = _videoRepository
            .savedVideoIdsStream(_userId!)
            .listen(_handleVideoIds);
      } else if (filterType.value == 'user') {
        // For user videos, load all videos by the user using pagination
        await _loadUserVideos();
      }
    } catch (e) {
      Get.log('Error loading filtered videos: $e', isError: true);
      error.value = 'Failed to load videos';
      isLoading.value = false;
    }
  }

  /// Schedules a jump to the initial video after the view has been built.
  /// This ensures pageController.hasClients is true.
  void _scheduleJumpToInitialVideo() {
    if (_initialVideoId == null) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_initialVideoId != null && pageController.hasClients) {
        final targetIndex = videos.indexWhere((v) => v.id == _initialVideoId);
        if (targetIndex != -1) {
          currentIndex.value = targetIndex;
          pageController.jumpToPage(targetIndex);
          Get.log('[FilteredVideoFeedController] Jumped to initial video at index $targetIndex');
        }
        _initialVideoId = null;
      } else if (_initialVideoId != null) {
        // If still no clients, try again next frame
        _scheduleJumpToInitialVideo();
      }
    });
  }

  /// Loads videos from pre-loaded search results.
  Future<void> _loadSearchVideos() async {
    try {
      isLoading.value = true;
      videos.clear();
      
      if (_preloadedVideos == null || _preloadedVideos!.isEmpty) {
        error.value = 'No videos to display';
        isLoading.value = false;
        return;
      }
      
      // Process videos for signed URLs if needed
      for (final video in _preloadedVideos!) {
        final processedVideo = await _ensureSignedUrl(video);
        videos.add(processedVideo);
      }
      
      // Jump to initial video if specified
      if (_initialVideoId != null) {
        _scheduleJumpToInitialVideo();
      }
      
      // Start tracking watch time for the first video
      if (videos.isNotEmpty) {
        _startWatchTimeTracking(currentIndex.value);
      }
      
      isLoading.value = false;
    } catch (e) {
      Get.log('Error loading search videos: $e', isError: true);
      error.value = 'Failed to load videos';
      isLoading.value = false;
    }
  }

  Future<void> _loadUserVideos() async {
    try {
      isLoading.value = true;
      videos.clear();
      
      // Check if viewing own profile
      final currentUserId = _authService.currentUser.value?.uid;
      final isOwnProfile = _userId == currentUserId;
      
      // Load user videos with pagination (load all for feed experience)
      DocumentSnapshot<Map<String, dynamic>>? lastDoc;
      bool hasMore = true;
      
      while (hasMore) {
        final page = await _videoRepository.getUserVideosPage(
          _userId!,
          limit: 50,
          startAfter: lastDoc,
          isOwnProfile: isOwnProfile, // Privacy filter for other users' profiles
        );
        
        videos.addAll(page.items);
        lastDoc = page.lastDoc;
        hasMore = page.hasMore;
        
        // Break after reasonable number to avoid excessive loading
        if (videos.length >= 200) break;
      }
      
      // Jump to initial video if specified
      // Use post-frame callback to ensure the PageView has attached clients
      if (_initialVideoId != null) {
        _scheduleJumpToInitialVideo();
      }
      
      // Start tracking watch time for the first video
      if (videos.isNotEmpty) {
        _startWatchTimeTracking(currentIndex.value);
      }
      
      isLoading.value = false;
    } catch (e) {
      Get.log('Error loading user videos: $e', isError: true);
      error.value = 'Failed to load user videos';
      isLoading.value = false;
    }
  }

  void _handleVideoIds(List<String> videoIds) {
    Get.log('Filtered feed received ${videoIds.length} video IDs');

    // Cancel subscriptions for videos no longer in the list
    for (final entry in _videoSubscriptions.entries.toList()) {
      if (!videoIds.contains(entry.key)) {
        entry.value.cancel();
        _videoSubscriptions.remove(entry.key);
      }
    }

    // Subscribe to new video IDs
    for (final videoId in videoIds) {
      if (_videoSubscriptions.containsKey(videoId)) continue;

      _videoSubscriptions[videoId] = _videoRepository
          .watchVideo(videoId)
          .listen((video) async {
        if (video != null) {
          final processedVideo = await _ensureSignedUrl(video);
          // Update or add video in the list
          final index = videos.indexWhere((v) => v.id == videoId);
          if (index != -1) {
            videos[index] = processedVideo;
          } else {
            videos.add(processedVideo);
            // Maintain order based on videoIds
            _sortVideos(videoIds);
          }
          
          // Jump to initial video if this is it and we haven't jumped yet
          if (_initialVideoId != null && processedVideo.id == _initialVideoId) {
            _scheduleJumpToInitialVideo();
          }
        } else {
          // Video was deleted or is no longer accessible
          videos.removeWhere((v) => v.id == videoId);
        }

        isLoading.value = false;
      });
    }

    // If no videos remain, update loading state
    if (videoIds.isEmpty) {
      videos.clear();
      isLoading.value = false;
    }
  }

  void _sortVideos(List<String> videoIds) {
    // Sort videos based on the order in videoIds
    videos.sort((a, b) {
      final aIndex = videoIds.indexOf(a.id);
      final bIndex = videoIds.indexOf(b.id);
      return aIndex.compareTo(bIndex);
    });
  }

  Future<VideoModel> _ensureSignedUrl(VideoModel video) async {
    final privacy = video.privacy?.trim().toLowerCase();
    if (privacy == 'private' || privacy == 'followers-only') {
      try {
        final signedUrl = await _videoRepository.getSignedVideoUrl(video.id);
        return video.copyWith(hlsUrl: signedUrl);
      } catch (e) {
        Get.log('Failed to sign video ${video.id}: $e', isError: true);
      }
    }
    return video;
  }

  void onPageChanged(int index) {
    // Log watch time for previous video before switching
    _logWatchTimeForPreviousVideo();
    
    currentIndex.value = index;
    
    // Start tracking watch time for new video
    _startWatchTimeTracking(index);
    
    Get.log('Filtered feed page changed to $index');
  }
  
  /// Start tracking watch time for the video at the given index.
  void _startWatchTimeTracking(int index) {
    if (index < 0 || index >= videos.length) return;
    
    final videoId = videos[index].id;
    _videoWatchStartTimes[videoId] = DateTime.now();
    
    Get.log('[FilteredVideoFeedController] Started watch time tracking for video: $videoId');
  }
  
  /// Log watch time and increment view count if watched >= 3 seconds.
  void _logWatchTimeForPreviousVideo() {
    final prevIndex = currentIndex.value;
    if (prevIndex < 0 || prevIndex >= videos.length) return;
    
    final video = videos[prevIndex];
    final videoId = video.id;
    
    if (_videoWatchStartTimes.containsKey(videoId)) {
      final startTime = _videoWatchStartTimes[videoId]!;
      final watchDurationSeconds = DateTime.now().difference(startTime).inSeconds;
      
      // Accumulate total watch duration
      _videoWatchDurations[videoId] = 
          (_videoWatchDurations[videoId] ?? 0) + watchDurationSeconds;
      
      final totalWatchDuration = _videoWatchDurations[videoId]!;
      
      // Increment view count if watched >= 3 seconds and not already counted
      if (totalWatchDuration >= 3 && !_viewCountedVideoIds.contains(videoId)) {
        _viewCountedVideoIds.add(videoId);
        _videoRepository.incrementViewCount(videoId);
        Get.log('[FilteredVideoFeedController] Incremented view count for video: $videoId');
      }
      
      Get.log('[FilteredVideoFeedController] Watch duration for $videoId: ${totalWatchDuration}s');
      
      // Clear tracking
      _videoWatchStartTimes.remove(videoId);
      _videoWatchDurations.remove(videoId);
    }
  }

  // Callback methods for video interactions
  void openCreatorProfile(VideoModel video) {
    Get.toNamed(Routes.profile, arguments: {'userId': video.ownerId});
  }

  Future<void> handleLikeTap(VideoModel video) async {
    final userId = _authService.currentUser.value?.uid;
    if (userId == null) return;

    try {
      // Use SocialService so like actions also produce notifications
      await _socialService.toggleLike(
        videoId: video.id,
        userId: userId,
        video: video,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update like',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    }
  }

  void openComments(VideoModel video) {
    Get.toNamed(Routes.comments, arguments: {
      'videoId': video.id,
      'video': video,
    });
  }

  Future<void> shareVideo(VideoModel video) async {
    final userId = _authService.currentUser.value?.uid;
    if (userId == null) return;

    try {
      await _socialService.shareVideo(
        video: video,
        userId: userId,
      );
      
      Get.snackbar(
        'Success',
        'Video shared successfully',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to share video',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    }
  }

  Future<void> toggleBookmark(VideoModel video) async {
    final userId = _authService.currentUser.value?.uid;
    if (userId == null) return;

    try {
      final wasSaved = await _socialService.toggleBookmark(
        videoId: video.id,
        userId: userId,
      );
      
      Get.snackbar(
        'Success',
        wasSaved ? 'Saved to collection' : 'Removed from saved',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 1),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update bookmark',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  void onClose() {
    // Log watch time for current video before closing
    _logWatchTimeForPreviousVideo();
    
    _videoIdsSubscription?.cancel();
    for (final subscription in _videoSubscriptions.values) {
      subscription.cancel();
    }
    _videoSubscriptions.clear();
    pageController.dispose();
    super.onClose();
  }
}
