import 'dart:async';

import 'package:get_storage/get_storage.dart';

import '../../data/models/video_model.dart';

/// Metadata for persistent cache entries
class _PersistentCacheEntry {
  _PersistentCacheEntry({
    required this.video,
    required this.cachedAt,
    required this.expiresAt,
  });

  factory _PersistentCacheEntry.fromJson(Map<String, dynamic> json) {
    return _PersistentCacheEntry(
      video: VideoModel.fromJson(json['video'] as Map<String, dynamic>),
      cachedAt: DateTime.parse(json['cachedAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  final VideoModel video;
  final DateTime cachedAt;
  final DateTime expiresAt;

  Map<String, dynamic> toJson() {
    return {
      'video': video.toJson(),
      'cachedAt': cachedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Persistent cache service using GetStorage for L2 cache layer
/// 
/// Features:
/// - FIFO (First-In-First-Out) eviction when maxSize reached
/// - 24-hour default TTL for cached videos
/// - Automatic expired entry cleanup
/// - JSON serialization/deserialization
/// - Queue-based insertion order tracking
class VideoPersistentCache {
  VideoPersistentCache({
    this.maxSize = 100,
  });

  final int maxSize;

  static const String _boxName = 'video_feed_cache';
  static const String _queueKey = '_insertion_queue';
  
  late final GetStorage _storage;
  final List<String> _insertionQueue = [];
  
  // Lock for thread-safe concurrent operations
  bool _isLocked = false;
  final List<Completer<void>> _lockQueue = [];

  /// Acquire lock for thread-safe operations
  Future<void> _acquireLock() async {
    // If already locked, wait in queue
    if (_isLocked) {
      final completer = Completer<void>();
      _lockQueue.add(completer);
      await completer.future;
    }
    // Mark as locked
    _isLocked = true;
  }

  /// Release lock after operation
  void _releaseLock() {
    // If there are waiting operations, complete the next one
    if (_lockQueue.isNotEmpty) {
      final next = _lockQueue.removeAt(0);
      next.complete();
    } else {
      // Otherwise, mark as unlocked
      _isLocked = false;
    }
  }

  /// Initialize GetStorage and load insertion queue
  Future<void> initialize() async {
    await GetStorage.init(_boxName);
    _storage = GetStorage(_boxName);
    
    // Load insertion queue from storage
    final queueData = _storage.read<List>(_queueKey);
    if (queueData != null) {
      _insertionQueue.addAll(queueData.cast<String>());
    }
  }

  /// Get video from persistent cache
  Future<VideoModel?> getVideo(String videoId) async {
    try {
      final data = _storage.read<Map<String, dynamic>>(videoId);
      if (data == null) return null;

      final entry = _PersistentCacheEntry.fromJson(data);
      
      // Check expiration
      if (entry.isExpired) {
        await deleteVideo(videoId);
        return null;
      }

      return entry.video;
    } catch (e) {
      // Corrupt data - remove entry
      await deleteVideo(videoId);
      return null;
    }
  }

  /// Save video to persistent cache
  Future<void> saveVideo(
    VideoModel video, {
    Duration ttl = const Duration(hours: 24),
  }) async {
    await _acquireLock();
    
    try {
      // Check if cache is full
      if (_insertionQueue.length >= maxSize && !_insertionQueue.contains(video.id)) {
        // Evict oldest entry (FIFO)
        await _evictOldest();
      }

      final now = DateTime.now();
      final entry = _PersistentCacheEntry(
        video: video,
        cachedAt: now,
        expiresAt: now.add(ttl),
      );

      // Save entry
      await _storage.write(video.id, entry.toJson());

      // Update insertion queue
      if (!_insertionQueue.contains(video.id)) {
        _insertionQueue.add(video.id);
        await _saveQueue();
      }
    } finally {
      _releaseLock();
    }
  }

  /// Save multiple videos to persistent cache
  Future<void> saveVideos(
    List<VideoModel> videos, {
    Duration ttl = const Duration(hours: 24),
  }) async {
    for (final video in videos) {
      await saveVideo(video, ttl: ttl);
    }
  }

  /// Delete a specific video from cache
  Future<void> deleteVideo(String videoId) async {
    await _storage.remove(videoId);
    _insertionQueue.remove(videoId);
    await _saveQueue();
  }

  /// Clear all cached videos
  Future<void> clearAll() async {
    // Remove all video entries (keep queue key)
    for (final videoId in List.from(_insertionQueue)) {
      await _storage.remove(videoId);
    }
    
    _insertionQueue.clear();
    await _saveQueue();
  }

  /// Clear expired entries from cache
  Future<void> clearExpired() async {
    final expiredIds = <String>[];

    for (final videoId in _insertionQueue) {
      try {
        final data = _storage.read<Map<String, dynamic>>(videoId);
        if (data == null) {
          expiredIds.add(videoId);
          continue;
        }

        final entry = _PersistentCacheEntry.fromJson(data);
        if (entry.isExpired) {
          expiredIds.add(videoId);
        }
      } catch (e) {
        // Corrupt entry - mark for deletion
        expiredIds.add(videoId);
      }
    }

    // Remove expired entries
    for (final id in expiredIds) {
      await deleteVideo(id);
    }
  }

  /// Evict oldest entry (FIFO)
  Future<void> _evictOldest() async {
    if (_insertionQueue.isEmpty) return;

    final oldestId = _insertionQueue.removeAt(0);
    await _storage.remove(oldestId);
    await _saveQueue();
  }

  /// Save insertion queue to storage
  Future<void> _saveQueue() async {
    await _storage.write(_queueKey, _insertionQueue);
  }

  /// Get cache size
  int get size => _insertionQueue.length;

  /// Check if video is cached
  bool hasVideo(String videoId) {
    return _insertionQueue.contains(videoId);
  }

  /// Get most recent non-expired videos (LIFO from insertion queue).
  Future<List<VideoModel>> getRecentVideos({int limit = 20}) async {
    await _acquireLock();

    try {
      final results = <VideoModel>[];
      final expiredIds = <String>[];

      for (final id in _insertionQueue.reversed) {
        if (results.length >= limit) break;

        try {
          final data = _storage.read<Map<String, dynamic>>(id);
          if (data == null) {
            expiredIds.add(id);
            continue;
          }

          final entry = _PersistentCacheEntry.fromJson(data);
          if (entry.isExpired) {
            expiredIds.add(id);
            continue;
          }

          results.add(entry.video);
        } catch (_) {
          expiredIds.add(id);
        }
      }

      // Clean up any expired or corrupt entries encountered
      for (final id in expiredIds) {
        await deleteVideo(id);
      }

      return results;
    } finally {
      _releaseLock();
    }
  }
}
