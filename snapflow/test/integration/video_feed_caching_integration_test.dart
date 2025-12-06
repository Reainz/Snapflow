import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:snapflow/app/core/services/connectivity_service.dart';
import 'package:snapflow/app/core/services/video_feed_cache_service.dart';
import 'package:snapflow/app/data/models/video_model.dart';
import 'package:snapflow/app/data/repositories/video_repository.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Mock path_provider for GetStorage and Firebase
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.path;
        }
        return null;
      },
    );
    
    // Mock Firebase Core
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_core'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'Firebase#initializeCore') {
          return {
            'name': '[DEFAULT]',
            'options': {
              'apiKey': 'test-key',
              'appId': 'test-app-id',
              'messagingSenderId': 'test-sender-id',
              'projectId': 'test-project-id',
            },
            'pluginConstants': {},
          };
        }
        return null;
      },
    );
    
    // Mock Firebase Analytics
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_analytics'),
      (MethodCall methodCall) async {
        return null; // No-op for analytics in tests
      },
    );
  });
  
  group('Video Feed Caching Integration', () {
    late VideoFeedCacheService cacheService;
    late VideoRepository videoRepository;
    late ConnectivityService connectivityService;
    
    setUp(() async {
      Get.testMode = true;
      
      // Use Get.lazyPut with fenix to trigger onInit when first accessed
      Get.lazyPut<VideoFeedCacheService>(
        () => VideoFeedCacheService(maxSize: 10, ttl: const Duration(minutes: 10)),
        fenix: true,
      );
      
      // Mock connectivity service
      Get.lazyPut<ConnectivityService>(() => ConnectivityService(), fenix: true);
      
      // Use Get.lazyPut with fenix to trigger onInit when first accessed
      Get.lazyPut<VideoRepository>(() => VideoRepository(), fenix: true);
      
      // Access services to trigger creation and onInit()
      cacheService = Get.find<VideoFeedCacheService>();
      connectivityService = Get.find<ConnectivityService>();
      videoRepository = Get.find<VideoRepository>();
      
      // Wait for async onInit to complete
      await Future.delayed(const Duration(milliseconds: 100));
    });
    
    tearDown(() async {
      await cacheService.clearCache();
      Get.reset();
    });
    
    test('getVideoById should return cached video on second call', () async {
      // This test verifies cache READ is working
      final videoId = 'test-video-123';
      
      // Manually cache a video (simulating Firestore fetch result)
      final testVideo = VideoModel(
        id: videoId,
        title: 'Test Video',
        description: 'Test Description',
        ownerId: 'user123',
        hlsUrl: 'https://test.cloudinary.com/video/test.m3u8',
        thumbnailUrl: 'https://test.cloudinary.com/thumbnail/test.jpg',
        duration: 30,
        viewsCount: 100,
        likesCount: 10,
        commentsCount: 5,
        isLiked: false,
        captionUrl: null,
        hasCaptions: false,
      );
      
      await cacheService.cacheVideo(testVideo);
      
      // Second call - should hit cache
      final result = await videoRepository.getVideoById(videoId);
      
      expect(result, isNotNull);
      expect(result!.id, equals(videoId));
      expect(result.title, equals('Test Video'));
      
      // Verify cache stats show a hit
      final stats = cacheService.getStats();
      expect(stats.hits, greaterThan(0));
      expect(stats.misses, equals(0)); // No misses because we pre-cached
    });
    
    test('cache hit rate should improve with repeated access', () async {
      // Test cache effectiveness over multiple accesses
      final videoIds = ['video1', 'video2', 'video3'];
      
      // Cache some videos
      for (final id in videoIds) {
        await cacheService.cacheVideo(VideoModel(
          id: id,
          title: 'Video $id',
          description: 'Description $id',
          ownerId: 'user123',
          hlsUrl: 'https://test.cloudinary.com/video/$id.m3u8',
          thumbnailUrl: 'https://test.cloudinary.com/thumbnail/$id.jpg',
          duration: 30,
          viewsCount: 100,
          likesCount: 10,
          commentsCount: 5,
          isLiked: false,
          captionUrl: null,
          hasCaptions: false,
        ));
      }
      
      // Access videos multiple times
      for (var i = 0; i < 5; i++) {
        for (final id in videoIds) {
          await videoRepository.getVideoById(id);
        }
      }
      
      // Verify high hit rate
      final stats = cacheService.getStats();
      expect(stats.hits, greaterThan(10)); // Should have many hits
      expect(stats.hitRate, greaterThan(0.8)); // >80% hit rate
    });
    
    test('cache should reduce Firestore reads', () async {
      // This test verifies that cache reduces backend calls
      final videoId = 'test-video-456';
      
      // Pre-cache a video
      final testVideo = VideoModel(
        id: videoId,
        title: 'Cached Video',
        description: 'This video is cached',
        ownerId: 'user123',
        hlsUrl: 'https://test.cloudinary.com/video/cached.m3u8',
        thumbnailUrl: 'https://test.cloudinary.com/thumbnail/cached.jpg',
        duration: 45,
        viewsCount: 500,
        likesCount: 50,
        commentsCount: 10,
        isLiked: false,
        captionUrl: null,
        hasCaptions: false,
      );
      
      await cacheService.cacheVideo(testVideo);
      
      final initialStats = cacheService.getStats();
      final initialHits = initialStats.hits;
      
      // Access the same video multiple times
      for (var i = 0; i < 10; i++) {
        final video = await videoRepository.getVideoById(videoId);
        expect(video, isNotNull);
        expect(video!.id, equals(videoId));
      }
      
      final finalStats = cacheService.getStats();
      final finalHits = finalStats.hits;
      
      // All 10 accesses should be cache hits (no Firestore reads)
      expect(finalHits - initialHits, equals(10));
      expect(finalStats.hitRate, greaterThan(0.9)); // >90% hit rate
    });
    
    test('offline mode should log appropriate messages', () async {
      // This test verifies offline handling
      // Note: We can't fully test Firestore offline behavior in unit tests,
      // but we can verify the cache service works when connectivity is offline
      
      // Set connectivity to offline
      connectivityService.isOnline.value = false;
      
      // Cache some videos
      final videos = [
        _createTestVideo('offline1', 'Offline Video 1'),
        _createTestVideo('offline2', 'Offline Video 2'),
      ];
      
      for (final video in videos) {
        await cacheService.cacheVideo(video);
      }
      
      // Verify we can retrieve cached videos even when offline
      for (final video in videos) {
        final retrieved = await videoRepository.getVideoById(video.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.id, equals(video.id));
      }
      
      final stats = cacheService.getStats();
      expect(stats.size, equals(2));
    });
    
    test('cache invalidation should remove video from cache', () async {
      // Test that invalidation works correctly
      final videoId = 'test-video-789';
      
      // Cache a video
      final testVideo = _createTestVideo(videoId, 'Test Video 789');
      await cacheService.cacheVideo(testVideo);
      
      // Verify it's in cache
      var cached = await videoRepository.getVideoById(videoId);
      expect(cached, isNotNull);
      
      // Invalidate the video
      await cacheService.invalidateVideo(videoId);
      
      // Try to get from cache again - should be null now
      // Note: getVideoById will try Firestore after cache miss,
      // so we check the cache directly
      final cachedAfterInvalidation = await cacheService.getVideo(videoId);
      expect(cachedAfterInvalidation, isNull);
    });
    
    test('cache statistics should be accurate', () async {
      // Test that cache statistics tracking works correctly
      final videos = [
        _createTestVideo('stat1', 'Stats Video 1'),
        _createTestVideo('stat2', 'Stats Video 2'),
        _createTestVideo('stat3', 'Stats Video 3'),
      ];
      
      // Cache all videos
      await cacheService.cacheVideos(videos);
      
      // Access each video twice (should be cache hits)
      for (final video in videos) {
        await videoRepository.getVideoById(video.id);
        await videoRepository.getVideoById(video.id);
      }
      
      final stats = cacheService.getStats();
      expect(stats.size, equals(3)); // 3 videos cached
      expect(stats.hits, equals(6)); // 6 cache hits (2 per video)
      expect(stats.hitRate, equals(1.0)); // 100% hit rate (no misses)
    });
  });
}

/// Helper function to create test video models
VideoModel _createTestVideo(String id, String title) {
  return VideoModel(
    id: id,
    ownerId: 'testUser',
    title: title,
    description: 'Test description for $title',
    hlsUrl: 'https://test.cloudinary.com/video/$id.m3u8',
    thumbnailUrl: 'https://test.cloudinary.com/thumbnail/$id.jpg',
    duration: 30,
    viewsCount: 100,
    likesCount: 10,
    commentsCount: 5,
    isLiked: false,
    captionUrl: null,
    hasCaptions: false,
  );
}
