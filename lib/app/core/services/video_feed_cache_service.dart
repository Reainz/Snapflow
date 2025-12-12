import 'dart:async';
import 'dart:collection';

import 'package:get/get.dart';

import '../../data/models/video_model.dart';
import 'video_persistent_cache.dart';

/// Statistics about cache performance
class CacheStats {
  CacheStats({
    required this.hits,
    required this.misses,
    required this.size,
    required this.maxSize,
  });

  final int hits;
  final int misses;
  final int size;
  final int maxSize;

  double get hitRate => (hits + misses) > 0 ? hits / (hits + misses) : 0.0;
}

/// Metadata for cached video entries
class _CachedVideoEntry {
  _CachedVideoEntry({
    required this.video,
    required this.timestamp,
    required this.expiresAt,
    this.hitCount = 0,
  });

  final VideoModel video;
  final DateTime timestamp;
  final DateTime expiresAt;
  int hitCount;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// In-memory cache service with LRU eviction for video feed
/// 
/// Features:
/// - LRU (Least Recently Used) eviction policy
/// - TTL (Time To Live) based expiration
/// - Thread-safe operations with async locks
/// - Cache statistics tracking
/// - Integration with persistent storage layer
class VideoFeedCacheService extends GetxService {
  VideoFeedCacheService({
    this.maxSize = 50,
    this.ttl = const Duration(minutes: 10),
    this.hydrationBatchSize = 20,
  });

  final int maxSize;
  final Duration ttl;
  final int hydrationBatchSize;

  final _cache = <String, _CachedVideoEntry>{};
  final _accessOrder = Queue<String>();
  final Queue<Completer<void>> _lockQueue = Queue<Completer<void>>();

  int _hits = 0;
  int _misses = 0;

  late final VideoPersistentCache _persistentCache;

  @override
  Future<void> onInit() async {
    super.onInit();
    _persistentCache = VideoPersistentCache();
    await _persistentCache.initialize();
    await _hydrateFromPersistent();
  }

  /// Acquire lock for thread-safe operations
  Future<void> _acquireLock() async {
    final completer = Completer<void>();
    _lockQueue.add(completer);

    // First in queue acquires immediately; others wait for predecessor
    if (_lockQueue.length == 1) {
      return;
    }

    // Wait for the previous operation to complete
    final previous = _lockQueue.elementAt(_lockQueue.length - 2);
    await previous.future;
  }

  /// Release lock after operation
  void _releaseLock() {
    if (_lockQueue.isEmpty) return;

    final completed = _lockQueue.removeFirst();
    if (!completed.isCompleted) {
      completed.complete();
    }
  }

  /// Get video from cache (checks in-memory first, then persistent cache)
  Future<VideoModel?> getVideo(String videoId) async {
    await _acquireLock();

    try {
      // Check in-memory cache first
      final entry = _cache[videoId];
      if (entry != null) {
        if (entry.isExpired) {
          // Remove expired entry from both cache layers
          _cache.remove(videoId);
          _accessOrder.remove(videoId);
          _misses++;
          // Remove from persistent cache as well
          await _persistentCache.deleteVideo(videoId);
          return null;
        }

        // Cache hit - update access order
        _hits++;
        entry.hitCount++;
        _updateAccessOrder(videoId);
        return entry.video;
      }

      // Cache miss - try persistent cache
      _misses++;
      return await _getFromPersistentCache(videoId);
    } finally {
      _releaseLock();
    }
  }

  /// Get video from persistent cache and load into memory
  Future<VideoModel?> _getFromPersistentCache(String videoId) async {
    final video = await _persistentCache.getVideo(videoId);
    if (video != null) {
      // Load into memory cache
      await _cacheInMemory(video);
    }
    return video;
  }

  /// Cache a single video in both memory and persistent storage
  Future<void> cacheVideo(VideoModel video) async {
    await _acquireLock();

    try {
      await _cacheInMemory(video);
      // Async write to persistent cache (non-blocking)
      _persistentCache.saveVideo(video, ttl: const Duration(hours: 24));
    } finally {
      _releaseLock();
    }
  }

  /// Internal method to cache video in memory only
  Future<void> _cacheInMemory(VideoModel video) async {
    // Check if cache is full
    if (_cache.length >= maxSize && !_cache.containsKey(video.id)) {
      // Evict LRU entry
      _evictLRU();
    }

    final now = DateTime.now();
    _cache[video.id] = _CachedVideoEntry(
      video: video,
      timestamp: now,
      expiresAt: now.add(ttl),
      hitCount: _cache[video.id]?.hitCount ?? 0,
    );

    _updateAccessOrder(video.id);
  }

  /// Get multiple videos from cache
  Future<List<VideoModel>> getVideos(List<String> videoIds) async {
    final videos = <VideoModel>[];
    for (final id in videoIds) {
      final video = await getVideo(id);
      if (video != null) {
        videos.add(video);
      }
    }
    return videos;
  }

  /// Cache multiple videos
  Future<void> cacheVideos(List<VideoModel> videos) async {
    for (final video in videos) {
      await cacheVideo(video);
    }
  }

  /// Update access order for LRU tracking
  void _updateAccessOrder(String videoId) {
    _accessOrder.remove(videoId);
    _accessOrder.addLast(videoId);
  }

  /// Evict least recently used entry
  void _evictLRU() {
    if (_accessOrder.isEmpty) return;

    final lruId = _accessOrder.removeFirst();
    _cache.remove(lruId);
    // Also remove from persistent cache to ensure complete eviction
    _persistentCache.deleteVideo(lruId);
  }

  /// Invalidate a specific video from all cache layers
  Future<void> invalidateVideo(String videoId) async {
    await _acquireLock();

    try {
      _cache.remove(videoId);
      _accessOrder.remove(videoId);
      await _persistentCache.deleteVideo(videoId);
    } finally {
      _releaseLock();
    }
  }

  /// Clear all cache layers
  Future<void> clearCache() async {
    await _acquireLock();

    try {
      _cache.clear();
      _accessOrder.clear();
      _hits = 0;
      _misses = 0;
      await _persistentCache.clearAll();
    } finally {
      _releaseLock();
    }
  }

  /// Prune expired entries from cache
  Future<void> pruneExpiredEntries() async {
    await _acquireLock();

    try {
      final expiredIds = <String>[];

      _cache.forEach((id, entry) {
        if (entry.isExpired) {
          expiredIds.add(id);
        }
      });

      for (final id in expiredIds) {
        _cache.remove(id);
        _accessOrder.remove(id);
      }

      // Also prune persistent cache
      await _persistentCache.clearExpired();
    } finally {
      _releaseLock();
    }
  }

  /// Get cache statistics
  CacheStats getStats() {
    return CacheStats(
      hits: _hits,
      misses: _misses,
      size: _cache.length,
      maxSize: maxSize,
    );
  }

  /// Get recent videos from cache (LRU order) up to [limit].
  Future<List<VideoModel>> getRecentVideos(int limit) async {
    await _acquireLock();

    try {
      final videos = <VideoModel>[];

      // Access order queue has most recent at end, so reverse iterate
      final accessList = _accessOrder.toList().reversed;

      for (final videoId in accessList) {
        if (videos.length >= limit) break;

        final entry = _cache[videoId];
        if (entry != null && !entry.isExpired) {
          videos.add(entry.video);
        }
      }

      return videos;
    } finally {
      _releaseLock();
    }
  }

  /// Get all non-expired videos from cache (sorted by hit count desc).
  Future<List<VideoModel>> getAllVideos() async {
    await _acquireLock();

    try {
      final videos = <VideoModel>[];

      for (final entry in _cache.values) {
        if (!entry.isExpired) {
          videos.add(entry.video);
        }
      }

      // Sort by hit count (most accessed first) for offline mode
      videos.sort((a, b) {
        final aEntry = _cache[a.id];
        final bEntry = _cache[b.id];
        if (aEntry == null || bEntry == null) return 0;
        return bEntry.hitCount.compareTo(aEntry.hitCount);
      });

      return videos;
    } finally {
      _releaseLock();
    }
  }

  /// Hydrate in-memory cache from persistent cache on startup for cache-first cold starts.
  Future<void> _hydrateFromPersistent() async {
    try {
      final batchSize = maxSize < hydrationBatchSize ? maxSize : hydrationBatchSize;
      final hydrated = await _persistentCache.getRecentVideos(limit: batchSize);

      await _acquireLock();
      try {
        for (final video in hydrated) {
          await _cacheInMemory(video);
        }
      } finally {
        _releaseLock();
      }

      if (hydrated.isNotEmpty) {
        Get.log('[VideoFeedCacheService] Hydrated ${hydrated.length} videos from persistent cache');
      }
    } catch (e) {
      Get.log('[VideoFeedCacheService] Hydration from persistent cache failed: $e', isError: true);
    }
  }

  @override
  void onClose() {
    _cache.clear();
    _accessOrder.clear();
    super.onClose();
  }
}
