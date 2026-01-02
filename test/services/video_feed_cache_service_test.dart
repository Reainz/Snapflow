import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:snapflow/app/core/services/video_feed_cache_service.dart';
import 'package:snapflow/app/data/models/video_model.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Directory? testDir;
  
  // Mock path_provider for GetStorage
  setUpAll(() {
    testDir = Directory.systemTemp.createTempSync('snapflow_test_cache_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return testDir!.path;
        }
        return null;
      },
    );
  });

  tearDownAll(() async {
    try {
      await testDir?.delete(recursive: true);
    } catch (_) {
      // Best-effort cleanup.
    }
  });
  
  late VideoFeedCacheService cacheService;

  setUp(() async {
    // Initialize GetX for testing
    Get.testMode = true;
    
    // Create cache service with test configuration
    cacheService = VideoFeedCacheService(
      maxSize: 5,
      ttl: const Duration(seconds: 2),
    );
    
    // Initialize the service (triggers onInit which initializes persistent cache)
    await cacheService.onInit();
  });

  tearDown(() async {
    // Clean up
    await cacheService.clearCache();
    Get.reset();
  });

  group('VideoFeedCacheService - Basic Operations', () {
    test('should cache and retrieve video', () async {
      // Arrange
      final video = _createTestVideo('video1', 'Test Video 1');

      // Act
      await cacheService.cacheVideo(video);
      final retrieved = await cacheService.getVideo('video1');

      // Assert
      expect(retrieved, isNotNull);
      expect(retrieved?.id, equals('video1'));
      expect(retrieved?.title, equals('Test Video 1'));
    });

    test('should return null for non-existent video', () async {
      // Act
      final retrieved = await cacheService.getVideo('nonexistent');

      // Assert
      expect(retrieved, isNull);
    });

    test('should cache multiple videos', () async {
      // Arrange
      final videos = [
        _createTestVideo('video1', 'Video 1'),
        _createTestVideo('video2', 'Video 2'),
        _createTestVideo('video3', 'Video 3'),
      ];

      // Act
      await cacheService.cacheVideos(videos);

      // Assert
      for (final video in videos) {
        final retrieved = await cacheService.getVideo(video.id);
        expect(retrieved, isNotNull);
        expect(retrieved?.id, equals(video.id));
      }
    });

    test('should retrieve multiple videos', () async {
      // Arrange
      final videos = [
        _createTestVideo('video1', 'Video 1'),
        _createTestVideo('video2', 'Video 2'),
        _createTestVideo('video3', 'Video 3'),
      ];
      await cacheService.cacheVideos(videos);

      // Act
      final retrieved = await cacheService.getVideos(['video1', 'video2', 'video3']);

      // Assert
      expect(retrieved.length, equals(3));
      expect(retrieved.map((v) => v.id).toSet(), equals({'video1', 'video2', 'video3'}));
    });
  });

  group('VideoFeedCacheService - LRU Eviction', () {
    test('should evict LRU video when cache full', () async {
      // Arrange
      final videos = [
        _createTestVideo('video1', 'Video 1'),
        _createTestVideo('video2', 'Video 2'),
        _createTestVideo('video3', 'Video 3'),
        _createTestVideo('video4', 'Video 4'),
        _createTestVideo('video5', 'Video 5'),
      ];

      // Fill cache to max capacity (5 videos)
      await cacheService.cacheVideos(videos);

      // Act - Add one more video (should evict video1 as LRU)
      final video6 = _createTestVideo('video6', 'Video 6');
      await cacheService.cacheVideo(video6);

      // Assert
      final video1Retrieved = await cacheService.getVideo('video1');
      final video6Retrieved = await cacheService.getVideo('video6');
      
      expect(video1Retrieved, isNull); // Should be evicted
      expect(video6Retrieved, isNotNull); // Should be cached
    });

    test('should update access order on cache hit', () async {
      // Arrange
      final videos = [
        _createTestVideo('video1', 'Video 1'),
        _createTestVideo('video2', 'Video 2'),
        _createTestVideo('video3', 'Video 3'),
        _createTestVideo('video4', 'Video 4'),
        _createTestVideo('video5', 'Video 5'),
      ];
      await cacheService.cacheVideos(videos);

      // Access video1 to make it most recently used
      await cacheService.getVideo('video1');

      // Act - Add one more video (should evict video2 as LRU)
      final video6 = _createTestVideo('video6', 'Video 6');
      await cacheService.cacheVideo(video6);

      // Assert
      final video1Retrieved = await cacheService.getVideo('video1');
      final video2Retrieved = await cacheService.getVideo('video2');
      
      expect(video1Retrieved, isNotNull); // Should NOT be evicted
      expect(video2Retrieved, isNull); // Should be evicted as LRU
    });
  });

  group('VideoFeedCacheService - TTL Expiration', () {
    test('should expire videos after TTL', () async {
      // Arrange
      final video = _createTestVideo('video1', 'Test Video 1');
      await cacheService.cacheVideo(video);

      // Verify video is cached
      final retrieved1 = await cacheService.getVideo('video1');
      expect(retrieved1, isNotNull);

      // Act - Wait for TTL to expire (2 seconds)
      await Future.delayed(const Duration(seconds: 3));

      // Assert
      final retrieved2 = await cacheService.getVideo('video1');
      expect(retrieved2, isNull); // Should be expired
    });

    test('should prune expired entries', () async {
      // Arrange
      final videos = [
        _createTestVideo('video1', 'Video 1'),
        _createTestVideo('video2', 'Video 2'),
        _createTestVideo('video3', 'Video 3'),
      ];
      await cacheService.cacheVideos(videos);

      // Wait for expiration
      await Future.delayed(const Duration(seconds: 3));

      // Act
      await cacheService.pruneExpiredEntries();
      final stats = cacheService.getStats();

      // Assert
      expect(stats.size, equals(0)); // All expired videos should be pruned
    });
  });

  group('VideoFeedCacheService - Cache Statistics', () {
    test('should track cache hits and misses', () async {
      // Arrange
      final video = _createTestVideo('video1', 'Test Video 1');
      await cacheService.cacheVideo(video);

      // Act
      await cacheService.getVideo('video1'); // Hit
      await cacheService.getVideo('video1'); // Hit
      await cacheService.getVideo('video2'); // Miss

      // Assert
      final stats = cacheService.getStats();
      expect(stats.hits, equals(2));
      expect(stats.misses, equals(1));
      expect(stats.hitRate, closeTo(0.666, 0.01));
    });

    test('should report cache size correctly', () async {
      // Arrange
      final videos = [
        _createTestVideo('video1', 'Video 1'),
        _createTestVideo('video2', 'Video 2'),
        _createTestVideo('video3', 'Video 3'),
      ];

      // Act
      await cacheService.cacheVideos(videos);
      final stats = cacheService.getStats();

      // Assert
      expect(stats.size, equals(3));
      expect(stats.maxSize, equals(5));
    });
  });

  group('VideoFeedCacheService - Cache Management', () {
    test('should invalidate specific video', () async {
      // Arrange
      final videos = [
        _createTestVideo('video1', 'Video 1'),
        _createTestVideo('video2', 'Video 2'),
        _createTestVideo('video3', 'Video 3'),
      ];
      await cacheService.cacheVideos(videos);

      // Act
      await cacheService.invalidateVideo('video2');

      // Assert
      final video1 = await cacheService.getVideo('video1');
      final video2 = await cacheService.getVideo('video2');
      final video3 = await cacheService.getVideo('video3');

      expect(video1, isNotNull);
      expect(video2, isNull); // Should be invalidated
      expect(video3, isNotNull);
    });

    test('should clear all cache', () async {
      // Arrange
      final videos = [
        _createTestVideo('video1', 'Video 1'),
        _createTestVideo('video2', 'Video 2'),
        _createTestVideo('video3', 'Video 3'),
      ];
      await cacheService.cacheVideos(videos);

      // Act
      await cacheService.clearCache();
      final stats = cacheService.getStats();

      // Assert
      expect(stats.size, equals(0));
      expect(stats.hits, equals(0));
      expect(stats.misses, equals(0));
    });
  });

  group('VideoFeedCacheService - Thread Safety', () {
    test('should handle concurrent cache operations', () async {
      // Arrange
      final videos = List.generate(
        20,
        (index) => _createTestVideo('video$index', 'Video $index'),
      );

      // Act - Concurrent cache and retrieve operations
      final futures = <Future>[];
      for (final video in videos) {
        futures.add(cacheService.cacheVideo(video));
      }
      for (final video in videos) {
        futures.add(cacheService.getVideo(video.id));
      }

      // Wait for all operations to complete
      await Future.wait(futures);

      // Assert - No exceptions should be thrown
      final stats = cacheService.getStats();
      expect(stats.size, greaterThan(0)); // Some videos should be cached
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
