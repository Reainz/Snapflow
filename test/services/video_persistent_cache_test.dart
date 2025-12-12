import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:snapflow/app/core/services/video_persistent_cache.dart';
import 'package:snapflow/app/data/models/video_model.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late VideoPersistentCache persistentCache;
  
  // Mock path_provider for GetStorage
  setUpAll(() async {
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
    
    // Initialize GetStorage for testing
    await GetStorage.init('video_feed_cache');
  });

  setUp(() async {
    // Create persistent cache with test configuration
    persistentCache = VideoPersistentCache(maxSize: 5);
    await persistentCache.initialize();
  });

  tearDown(() async {
    // Clean up
    await persistentCache.clearAll();
  });

  group('VideoPersistentCache - Basic Operations', () {
    test('should save and load video', () async {
      // Arrange
      final video = _createTestVideo('video1', 'Test Video 1');

      // Act
      await persistentCache.saveVideo(video);
      final retrieved = await persistentCache.getVideo('video1');

      // Assert
      expect(retrieved, isNotNull);
      expect(retrieved?.id, equals('video1'));
      expect(retrieved?.title, equals('Test Video 1'));
    });

    test('should return null for non-existent video', () async {
      // Act
      final retrieved = await persistentCache.getVideo('nonexistent');

      // Assert
      expect(retrieved, isNull);
    });

    test('should check if video exists', () async {
      // Arrange
      final video = _createTestVideo('video1', 'Test Video 1');
      await persistentCache.saveVideo(video);

      // Act & Assert
      expect(persistentCache.hasVideo('video1'), isTrue);
      expect(persistentCache.hasVideo('nonexistent'), isFalse);
    });

    test('should delete specific video', () async {
      // Arrange
      final video = _createTestVideo('video1', 'Test Video 1');
      await persistentCache.saveVideo(video);

      // Act
      await persistentCache.deleteVideo('video1');

      // Assert
      final retrieved = await persistentCache.getVideo('video1');
      expect(retrieved, isNull);
    });

    test('should report cache size correctly', () async {
      // Arrange
      final videos = [
        _createTestVideo('video1', 'Video 1'),
        _createTestVideo('video2', 'Video 2'),
        _createTestVideo('video3', 'Video 3'),
      ];

      // Act
      for (final video in videos) {
        await persistentCache.saveVideo(video);
      }

      // Assert
      expect(persistentCache.size, equals(3));
    });
  });

  group('VideoPersistentCache - FIFO Eviction', () {
    test('should evict oldest video when cache full', () async {
      // Arrange - Fill cache to max capacity (5 videos)
      final videos = [
        _createTestVideo('video1', 'Video 1'),
        _createTestVideo('video2', 'Video 2'),
        _createTestVideo('video3', 'Video 3'),
        _createTestVideo('video4', 'Video 4'),
        _createTestVideo('video5', 'Video 5'),
      ];

      for (final video in videos) {
        await persistentCache.saveVideo(video);
      }

      // Act - Add one more video (should evict video1 as oldest)
      final video6 = _createTestVideo('video6', 'Video 6');
      await persistentCache.saveVideo(video6);

      // Assert
      final video1Retrieved = await persistentCache.getVideo('video1');
      final video6Retrieved = await persistentCache.getVideo('video6');
      
      expect(video1Retrieved, isNull); // Should be evicted
      expect(video6Retrieved, isNotNull); // Should be cached
      expect(persistentCache.size, equals(5)); // Should stay at max size
    });

    test('should maintain insertion order', () async {
      // Arrange
      final videos = [
        _createTestVideo('video1', 'Video 1'),
        _createTestVideo('video2', 'Video 2'),
        _createTestVideo('video3', 'Video 3'),
      ];

      for (final video in videos) {
        await persistentCache.saveVideo(video);
      }

      // Fill to capacity and add two more
      await persistentCache.saveVideo(_createTestVideo('video4', 'Video 4'));
      await persistentCache.saveVideo(_createTestVideo('video5', 'Video 5'));
      await persistentCache.saveVideo(_createTestVideo('video6', 'Video 6'));
      await persistentCache.saveVideo(_createTestVideo('video7', 'Video 7'));

      // Assert - video1 and video2 should be evicted (oldest first)
      expect(persistentCache.hasVideo('video1'), isFalse);
      expect(persistentCache.hasVideo('video2'), isFalse);
      expect(persistentCache.hasVideo('video3'), isTrue);
      expect(persistentCache.hasVideo('video7'), isTrue);
    });
  });

  group('VideoPersistentCache - TTL Expiration', () {
    test('should expire videos after TTL', () async {
      // Arrange
      final video = _createTestVideo('video1', 'Test Video 1');
      await persistentCache.saveVideo(video, ttl: const Duration(seconds: 2));

      // Verify video is cached
      final retrieved1 = await persistentCache.getVideo('video1');
      expect(retrieved1, isNotNull);

      // Act - Wait for TTL to expire (2 seconds)
      await Future.delayed(const Duration(seconds: 3));

      // Assert
      final retrieved2 = await persistentCache.getVideo('video1');
      expect(retrieved2, isNull); // Should be expired
    });

    test('should clear only expired entries', () async {
      // Arrange
      final video1 = _createTestVideo('video1', 'Video 1');
      await persistentCache.saveVideo(video1, ttl: const Duration(seconds: 2));

      // Wait 1.5 seconds then add video2 (so video1 expires first)
      await Future.delayed(const Duration(milliseconds: 1500));
      final video2 = _createTestVideo('video2', 'Video 2');
      await persistentCache.saveVideo(video2, ttl: const Duration(seconds: 10));

      // Wait for video1 to expire but not video2
      await Future.delayed(const Duration(milliseconds: 1000));

      // Act
      await persistentCache.clearExpired();

      // Assert
      expect(persistentCache.hasVideo('video1'), isFalse); // Should be expired
      expect(persistentCache.hasVideo('video2'), isTrue); // Should still be cached
    });

    test('should handle custom TTL per video', () async {
      // Arrange - Save video with custom 1-second TTL
      final video = _createTestVideo('video1', 'Test Video 1');
      await persistentCache.saveVideo(video, ttl: const Duration(seconds: 1));

      // Wait for custom TTL to expire
      await Future.delayed(const Duration(milliseconds: 1500));

      // Act
      final retrieved = await persistentCache.getVideo('video1');

      // Assert
      expect(retrieved, isNull); // Should be expired after 1 second
    });
  });

  group('VideoPersistentCache - Data Integrity', () {
    test('should handle corrupt JSON gracefully', () async {
      // Arrange - Manually insert corrupt data
      final storage = GetStorage('video_feed_cache');
      await storage.write('video1', 'this is not valid JSON');

      // Act & Assert - Should not throw, should return null
      final retrieved = await persistentCache.getVideo('video1');
      expect(retrieved, isNull);
    });

    test('should persist insertion queue across restarts', () async {
      // Arrange
      final videos = [
        _createTestVideo('video1', 'Video 1'),
        _createTestVideo('video2', 'Video 2'),
        _createTestVideo('video3', 'Video 3'),
      ];

      for (final video in videos) {
        await persistentCache.saveVideo(video);
      }

      // Simulate restart by creating new instance
      final newCache = VideoPersistentCache(maxSize: 5);
      await newCache.initialize();

      // Fill to capacity and add one more to test FIFO
      await newCache.saveVideo(_createTestVideo('video4', 'Video 4'));
      await newCache.saveVideo(_createTestVideo('video5', 'Video 5'));
      await newCache.saveVideo(_createTestVideo('video6', 'Video 6'));

      // Assert - video1 should be evicted (oldest)
      expect(newCache.hasVideo('video1'), isFalse);
      expect(newCache.hasVideo('video2'), isTrue);
    });

    test('should handle missing or empty insertion queue', () async {
      // Arrange - Manually remove insertion queue
      final storage = GetStorage('video_feed_cache');
      await storage.remove('_insertion_queue');

      // Act - Initialize new cache
      final newCache = VideoPersistentCache(maxSize: 5);
      await newCache.initialize();

      // Assert - Should not throw
      final video = _createTestVideo('video1', 'Video 1');
      await newCache.saveVideo(video);
      final retrieved = await newCache.getVideo('video1');
      expect(retrieved, isNotNull);
    });
  });

  group('VideoPersistentCache - Cache Management', () {
    test('should clear all entries', () async {
      // Arrange
      final videos = [
        _createTestVideo('video1', 'Video 1'),
        _createTestVideo('video2', 'Video 2'),
        _createTestVideo('video3', 'Video 3'),
      ];

      for (final video in videos) {
        await persistentCache.saveVideo(video);
      }

      // Act
      await persistentCache.clearAll();

      // Assert
      expect(persistentCache.size, equals(0));
      for (final video in videos) {
        expect(persistentCache.hasVideo(video.id), isFalse);
      }
    });

    test('should handle multiple concurrent operations', () async {
      // Arrange
      final videos = List.generate(
        20,
        (index) => _createTestVideo('video$index', 'Video $index'),
      );

      // Act - Concurrent save operations
      final futures = videos.map((video) => persistentCache.saveVideo(video));
      await Future.wait(futures);

      // Assert - No exceptions should be thrown
      final cacheSize = persistentCache.size;
      expect(cacheSize, greaterThan(0));
      expect(cacheSize, lessThanOrEqualTo(5)); // Should not exceed max size
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
