import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_queue_service.dart';
import '../../core/services/video_feed_cache_service.dart';

import '../models/video_model.dart';

class ToggleLikeResult {
  ToggleLikeResult({required this.isLiked, required this.likesCount});

  final bool isLiked;
  final int likesCount;
}

/// A small page object to support pagination of videos.
class VideoPage {
  VideoPage({
    required this.items,
    this.lastDoc,
    this.lastCursor,
    required this.hasMore,
  });
  final List<VideoModel> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final String? lastCursor;
  final bool hasMore;
}

class FollowerChunkCursor {
  const FollowerChunkCursor({
    required this.chunkIndex,
    required this.docId,
    required this.createdAt,
  });

  final int chunkIndex;
  final String docId;
  final Timestamp? createdAt;

  Map<String, dynamic> toMap() => {
        'chunkIndex': chunkIndex,
        'docId': docId,
        'createdAt': createdAt?.millisecondsSinceEpoch,
      };

  factory FollowerChunkCursor.fromMap(Map<String, dynamic> map) => FollowerChunkCursor(
        chunkIndex: map['chunkIndex'] as int,
        docId: map['docId'] as String,
        createdAt: map['createdAt'] != null
            ? Timestamp.fromMillisecondsSinceEpoch(map['createdAt'] as int)
            : null,
      );
}

class FollowersFeedCursor {
  FollowersFeedCursor({
    List<FollowerChunkCursor>? followerChunks,
  }) : followerChunks = followerChunks ?? const <FollowerChunkCursor>[];

  final List<FollowerChunkCursor> followerChunks;

  String toJson() => jsonEncode({
        'followerChunks': followerChunks.map((c) => c.toMap()).toList(),
      });

  factory FollowersFeedCursor.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final followerChunks = (map['followerChunks'] as List?)
            ?.map((entry) => FollowerChunkCursor.fromMap(
                  (entry as Map).map((key, value) => MapEntry(key.toString(), value)),
                ))
            .toList() ??
        const <FollowerChunkCursor>[];
    return FollowersFeedCursor(followerChunks: followerChunks);
  }

  Future<Map<int, DocumentSnapshot<Map<String, dynamic>>>> toDocumentSnapshots(
    FirebaseFirestore firestore,
  ) async {
    final followersDocs = <int, DocumentSnapshot<Map<String, dynamic>>>{};

    for (final chunkCursor in followerChunks) {
      followersDocs[chunkCursor.chunkIndex] =
          await firestore.collection('videos').doc(chunkCursor.docId).get();
    }

    return followersDocs;
  }
}

class _QueryDocsResult {
  const _QueryDocsResult({
    required this.docs,
    required this.hasMore,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final bool hasMore;
}

class _FollowerEntry {
  const _FollowerEntry({
    required this.chunkIndex,
    required this.doc,
  });

  final int chunkIndex;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
}

class _FollowersQueryDocsResult {
  const _FollowersQueryDocsResult({
    required this.docs,
    required this.hasMore,
  });

  final List<_FollowerEntry> docs;
  final bool hasMore;
}

enum _FeedSource { public, followers }

class _FeedEntry {
  const _FeedEntry({
    required this.video,
    required this.snapshot,
    required this.createdAt,
    required this.source,
    this.chunkIndex,
  });

  final VideoModel video;
  final QueryDocumentSnapshot<Map<String, dynamic>> snapshot;
  final Timestamp? createdAt;
  final _FeedSource source;
  final int? chunkIndex;
}

/// Cache entry for following list with timestamp-based expiration.
class _FollowingCacheEntry {
  _FollowingCacheEntry({
    required this.followingIds,
    required this.timestamp,
  });
  
  final List<String> followingIds;
  final DateTime timestamp;
  
  /// Returns true if cache entry is older than 5 minutes.
  bool get isExpired {
    return DateTime.now().difference(timestamp) > const Duration(minutes: 5);
  }
}

class VideoRepository extends GetxService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseFunctions get _functions => FirebaseFunctions.instance;
  FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  late final VideoFeedCacheService _cacheService;

  // Following list cache with TTL
  final Map<String, _FollowingCacheEntry> _followingCache = {};

  @override
  void onInit() {
    super.onInit();
    _cacheService = Get.find<VideoFeedCacheService>();
  }

  /// Clears the following list cache for a specific user.
  /// Call this after follow/unfollow operations to invalidate stale data.
  void invalidateFollowingCache(String userId) {
    _followingCache.remove(userId);
  }

  /// Clears all following list caches.
  void clearFollowingCache() {
    _followingCache.clear();
  }

  Future<List<String>> getFollowingUserIds(String userId) async {
    // Check cache first
    final cached = _followingCache[userId];
    if (cached != null && !cached.isExpired) {
      return cached.followingIds;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .get();
      final followingIds = snapshot.docs.map((doc) => doc.id).toList();
      
      // Update cache
      _followingCache[userId] = _FollowingCacheEntry(
        followingIds: followingIds,
        timestamp: DateTime.now(),
      );
      
      return followingIds;
    } catch (e) {
      Get.log('getFollowingUserIds failed: $e', isError: true);
      return [];
    }
  }

  /// Fetches the latest ready videos for the global feed.
  Future<List<VideoModel>> fetchFeed({int limit = 10}) async {
    final page = await getFeedPage(limit: limit);
    return page.items;
  }

  /// Returns a page of videos for the global feed ordered by createdAt desc.
  /// Only includes videos with status 'ready'.
  /// 
  /// Uses cache-aside pattern:
  /// - Initial page (startAfter == null): Try cache first, fallback to Firestore
  /// - Pagination (startAfter != null): Always fetch from Firestore (cache doesn't support pagination)
  /// - After fetching from Firestore: Cache all videos for future use
  Future<VideoPage> getFeedPage({
    int limit = 10,
    dynamic startAfter,
  }) async {
    try {
      if (startAfter == null) {
        final cacheStats = _cacheService.getStats();
        final connectivityService = Get.find<ConnectivityService>();
        final isOnline = connectivityService.isOnline.value;

        // Try cache-first for initial load
        if (cacheStats.size >= limit) {
          Get.log('[VideoRepository] Attempting cache-first load (${cacheStats.size} videos available)');

          try {
            final cachedVideos = await _cacheService.getRecentVideos(limit);

            if (cachedVideos.length >= limit) {
              Get.log('[VideoRepository] Serving ${cachedVideos.length} videos from cache');

              if (!Get.testMode) {
                await _analytics.logEvent(
                  name: 'feed_served_from_cache',
                  parameters: {
                    'cache_size': cacheStats.size,
                    'videos_served': cachedVideos.length,
                  },
                );
              }

              return VideoPage(
                items: cachedVideos,
                lastDoc: null,
                lastCursor: null,
                hasMore: true,
              );
            }
          } catch (e) {
            Get.log('[VideoRepository] Cache read failed, falling back to Firestore: $e');
          }
        }

        // Offline fallback - serve whatever cache we have
        if (!isOnline && cacheStats.size > 0) {
          Get.log('[VideoRepository] OFFLINE MODE - serving all available cache');

          try {
            final cachedVideos = await _cacheService.getAllVideos();

            if (!Get.testMode) {
              await _analytics.logEvent(
                name: 'feed_served_offline',
                parameters: {'cache_size': cachedVideos.length},
              );
            }

            return VideoPage(
              items: cachedVideos.take(limit).toList(),
              lastDoc: null,
              lastCursor: null,
              hasMore: false,
            );
          } catch (e) {
            Get.log('[VideoRepository] Offline cache read failed: $e', isError: true);
            return VideoPage(items: const [], lastDoc: null, lastCursor: null, hasMore: false);
          }
        }

        if (cacheStats.size > 0) {
          Get.log('[VideoRepository] Cache stats: ${cacheStats.size} videos, ${(cacheStats.hitRate * 100).toStringAsFixed(1)}% hit rate');
        }
      }

      return _fetchPublicFeedPage(
        limit: limit,
        startAfter: startAfter is DocumentSnapshot<Map<String, dynamic>> ? startAfter : null,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        Get.log(
          'Missing Firestore index for global video feed. Deploy firestore.indexes.json via "firebase deploy --only firestore:indexes".',
        );
        throw Exception(
          'Missing Firestore index for global video feed query. Deploy firestore.indexes.json via "firebase deploy --only firestore:indexes".',
        );
      }
      rethrow;
    }
  }

  Future<VideoPage> getFollowersOnlyFeedPage({
    int limit = 10,
    dynamic startAfter,
    List<String>? followedUserIds,
  }) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        return VideoPage(items: const [], lastDoc: null, lastCursor: null, hasMore: false);
      }

      final followerIds = followedUserIds ?? await getFollowingUserIds(currentUserId);
      if (followerIds.isEmpty) {
        return VideoPage(items: const [], lastDoc: null, lastCursor: null, hasMore: false);
      }

      Map<int, DocumentSnapshot<Map<String, dynamic>>> followerCursors = {};
      if (startAfter is String && startAfter.isNotEmpty) {
        final cursor = FollowersFeedCursor.fromJson(startAfter);
        followerCursors = await cursor.toDocumentSnapshots(_firestore);
      }

      final followersResult = await _fetchFollowersOnlyDocs(
        followedUserIds: followerIds,
        limit: limit,
        startAfter: followerCursors,
      );

      final entries = followersResult.docs
          .map(
            (entry) => _FeedEntry(
              video: _videoFromDoc(entry.doc),
              snapshot: entry.doc,
              createdAt: _timestampFromDoc(entry.doc),
              source: _FeedSource.followers,
              chunkIndex: entry.chunkIndex,
            ),
          )
          .toList()
        ..sort(_compareEntries);

      final items = <VideoModel>[];
      final Map<int, QueryDocumentSnapshot<Map<String, dynamic>>> lastFollowerDocs = {};

      for (final entry in entries) {
        if (items.length >= limit) break;
        items.add(entry.video);
        if (entry.chunkIndex != null) {
          lastFollowerDocs[entry.chunkIndex!] = entry.snapshot;
        }
      }

      if (items.isNotEmpty) {
        _cacheService.cacheVideos(items).catchError((e) {
          Get.log('[VideoRepository] Failed to cache followers-only videos: $e', isError: true);
        });
      }

      final lastCursor = lastFollowerDocs.isEmpty
          ? null
          : FollowersFeedCursor(
              followerChunks: lastFollowerDocs.entries
                  .map(
                    (entry) => FollowerChunkCursor(
                      chunkIndex: entry.key,
                      docId: entry.value.id,
                      createdAt: _timestampFromDoc(entry.value),
                    ),
                  )
                  .toList(),
            ).toJson();

      final hasMore = followersResult.hasMore;

      return VideoPage(
        items: items,
        lastDoc: null,
        lastCursor: lastCursor,
        hasMore: hasMore,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        Get.log(
          'Missing Firestore index for followers-only video feed. Deploy firestore.indexes.json via "firebase deploy --only firestore:indexes".',
        );
      }
      rethrow;
    }
  }

  Future<VideoPage> _fetchPublicFeedPage({
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final result = await _fetchPublicDocs(limit: limit, startAfter: startAfter);
    final items = result.docs.map(_videoFromDoc).toList();

    if (items.isNotEmpty) {
      _cacheService.cacheVideos(items).catchError((e) {
        Get.log('[VideoRepository] Failed to cache videos: $e', isError: true);
      });
    }

    final lastDoc = result.docs.isNotEmpty ? result.docs.last : null;
    return VideoPage(
      items: items,
      lastDoc: lastDoc,
      lastCursor: null,
      hasMore: result.hasMore,
    );
  }

  Future<_QueryDocsResult> _fetchPublicDocs({
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('videos')
        .where('status', isEqualTo: 'ready')
        .where('privacy', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get();
    return _QueryDocsResult(docs: snap.docs, hasMore: snap.docs.length == limit);
  }

  Future<_FollowersQueryDocsResult> _fetchFollowersOnlyDocs({
    required List<String> followedUserIds,
    required int limit,
    required Map<int, DocumentSnapshot<Map<String, dynamic>>> startAfter,
  }) async {
    if (followedUserIds.isEmpty) {
      return const _FollowersQueryDocsResult(docs: [], hasMore: false);
    }

    final chunks = _chunkList(followedUserIds, 10);
    final docs = <_FollowerEntry>[];

    for (var i = 0; i < chunks.length; i++) {
      final owners = chunks[i];
      if (owners.isEmpty) continue;

      Query<Map<String, dynamic>> query = _firestore
          .collection('videos')
          .where('status', isEqualTo: 'ready')
          .where('privacy', whereIn: ['public', 'followers-only'])
          .where('ownerId', whereIn: owners)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      final startAfterDoc = startAfter[i];
      if (startAfterDoc != null) {
        query = query.startAfterDocument(startAfterDoc);
      }

      final snap = await query.get();

      docs.addAll(
        snap.docs.map(
          (doc) => _FollowerEntry(chunkIndex: i, doc: doc),
        ),
      );
    }

    return _FollowersQueryDocsResult(
      docs: docs,
      hasMore: docs.length >= limit,
    );
  }

  int _compareEntries(_FeedEntry a, _FeedEntry b) {
    final aMs = a.createdAt?.millisecondsSinceEpoch ?? 0;
    final bMs = b.createdAt?.millisecondsSinceEpoch ?? 0;
    if (aMs != bMs) {
      return bMs.compareTo(aMs);
    }
    return a.snapshot.id.compareTo(b.snapshot.id);
  }

  List<List<String>> _chunkList(List<String> source, int chunkSize) {
    if (source.isEmpty) return const <List<String>>[];
    final chunks = <List<String>>[];
    for (var i = 0; i < source.length; i += chunkSize) {
      final end = (i + chunkSize) > source.length ? source.length : i + chunkSize;
      chunks.add(source.sublist(i, end));
    }
    return chunks;
  }

  Timestamp? _timestampFromDoc(DocumentSnapshot<Map<String, dynamic>>? doc) {
    final data = doc?.data();
    if (data == null) return null;
    final value = data['createdAt'];
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is int) return Timestamp.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return Timestamp.fromDate(parsed);
    }
    return null;
  }

  VideoModel _videoFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return VideoModel.fromJson({
      ...doc.data(),
      'id': doc.id,
    });
  }

  Future<List<VideoModel>> _searchFollowersOnlyVideos({
    required String normalizedQuery,
    required String normalizedHashtag,
    required List<String> followedUserIds,
    required int limit,
    required Set<String> seen,
  }) async {
    final matches = <VideoModel>[];
    final chunks = _chunkList(followedUserIds, 10);

    for (final chunk in chunks) {
      if (chunk.isEmpty) continue;
      final snap = await _firestore
          .collection('videos')
          .where('status', isEqualTo: 'ready')
          .where('privacy', whereIn: ['public', 'followers-only'])
          .where('ownerId', whereIn: chunk)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        if (!seen.add(doc.id)) continue;
        if (_matchesSearchQuery(data, normalizedQuery, normalizedHashtag)) {
          matches.add(
            VideoModel.fromJson({
              ...data,
              'id': doc.id,
            }),
          );
          if (matches.length >= limit) {
            return matches;
          }
        }
      }
    }

    return matches;
  }

  bool _matchesSearchQuery(
    Map<String, dynamic> data,
    String normalizedQuery,
    String normalizedHashtag,
  ) {
    final titleLower = (data['titleLower'] as String? ?? data['title'] as String? ?? '').toLowerCase();
    final hashtags = (data['hashtags'] as List?)?.map((e) => e.toString().toLowerCase()).toList() ?? const [];
    final matchesTitle = titleLower.contains(normalizedQuery);
    final matchesHashtag = hashtags.contains(normalizedHashtag.toLowerCase());
    return matchesTitle || matchesHashtag;
  }

  Stream<List<_FeedEntry>> _publicFeedStreamEntries(int limit) {
    final query = _firestore
        .collection('videos')
        .where('status', isEqualTo: 'ready')
        .where('privacy', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    return query.snapshots().map(
          (snap) => _mapSnapshotToEntries(snap.docs, _FeedSource.public),
        );
  }

  Stream<List<_FeedEntry>> _followersFeedStreamEntries(List<String> followedUserIds, int limit) {
    if (followedUserIds.isEmpty) {
      return Stream.value(const <_FeedEntry>[]);
    }

    final controller = StreamController<List<_FeedEntry>>();
    final chunks = _chunkList(followedUserIds, 10);
    final Map<int, List<_FeedEntry>> latestByChunk = {};
    final subscriptions = <StreamSubscription<List<_FeedEntry>>>[];

    void emit() {
      final merged = latestByChunk.values.expand((entries) => entries).toList()
        ..sort(_compareEntries);
      controller.add(merged.take(limit).toList());
    }

    for (var i = 0; i < chunks.length; i++) {
      final owners = chunks[i];
      if (owners.isEmpty) continue;

      final query = _firestore
          .collection('videos')
          .where('status', isEqualTo: 'ready')
          .where('privacy', whereIn: ['public', 'followers-only'])
          .where('ownerId', whereIn: owners)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      final sub = query.snapshots().map(
            (snap) => _mapSnapshotToEntries(snap.docs, _FeedSource.followers, chunkIndex: i),
          ).listen(
            (entries) {
              latestByChunk[i] = entries;
              emit();
            },
            onError: controller.addError,
          );

      subscriptions.add(sub);
    }

    controller.onCancel = () async {
      for (final sub in subscriptions) {
        await sub.cancel();
      }
    };

    return controller.stream;
  }

  List<_FeedEntry> _mapSnapshotToEntries(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    _FeedSource source, {
    int? chunkIndex,
  }) {
    return docs
        .map(
          (doc) => _FeedEntry(
            video: _videoFromDoc(doc),
            snapshot: doc,
            createdAt: _timestampFromDoc(doc),
            source: source,
            chunkIndex: chunkIndex,
          ),
        )
        .toList();
  }

  Future<void> uploadVideo(VideoModel model) async {
    // TODO: Upload metadata to Firestore.
    Get.log('Uploading video ${model.title}');
  }

  /// Get a single video by ID, checking cache first before Firestore.
  /// 
  /// Cache-first strategy:
  /// 1. Check L1 in-memory cache for instant retrieval
  /// 2. If cache miss, fetch from Firestore
  /// 3. Cache the result for future requests
  /// 
  /// Returns null if video doesn't exist.
  Future<VideoModel?> getVideoById(String videoId) async {
    try {
      // Check cache first
      final cachedVideo = await _cacheService.getVideo(videoId);
      if (cachedVideo != null) {
        Get.log('[VideoRepository] ✓ Cache HIT for video $videoId');
        // Avoid Firebase Analytics during widget tests to prevent the need for Firebase.initializeApp()
        if (!Get.testMode) {
          await _analytics.logEvent(
            name: 'cache_hit',
            parameters: {'video_id': videoId, 'cache_type': 'video_by_id'},
          );
        }
        return cachedVideo;
      }
      
      Get.log('[VideoRepository] ✗ Cache MISS for video $videoId - fetching from Firestore');
      
      // Fetch from Firestore
      final doc = await _firestore.collection('videos').doc(videoId).get();
      if (!doc.exists) {
        Get.log('[VideoRepository] Video $videoId not found in Firestore');
        return null;
      }
      
      final video = VideoModel.fromJson({
        ...doc.data()!,
        'id': doc.id,
      });
      
      // Cache for future use (fire-and-forget)
      _cacheService.cacheVideo(video).catchError((e) {
        Get.log('[VideoRepository] Failed to cache video: $e', isError: true);
      });
      
      if (!Get.testMode) {
        await _analytics.logEvent(
          name: 'cache_miss',
          parameters: {'video_id': videoId, 'cache_type': 'video_by_id'},
        );
      }
      
      return video;
    } catch (e) {
      Get.log('[VideoRepository] getVideoById failed: $e', isError: true);
      rethrow;
    }
  }

  Future<void> createVideoDraft({
    required String videoId,
    required String ownerId,
    required String title,
    required String description,
    required List<String> hashtags,
    required String rawVideoUrl,
    required String rawVideoStoragePath,
    String? thumbnailUrl,
    String? thumbnailStoragePath,
    int? thumbnailTimeMs,
    required int durationSeconds,
    required int fileSizeBytes,
    required String privacy,
    String? filterUsed,
  }) async {
    debugPrint('📦 [VideoRepository] Creating video draft...');
    debugPrint('📦 [VideoRepository] Video ID: $videoId');
    debugPrint('📦 [VideoRepository] Owner ID: $ownerId');
    Get.log('[VideoRepository] Creating video draft...');
    Get.log('[VideoRepository] Video ID: $videoId');
    Get.log('[VideoRepository] Owner ID: $ownerId');
    
    final now = FieldValue.serverTimestamp();
    debugPrint('📦 [VideoRepository] Payload timestamp prepared');

    final payload = <String, dynamic>{
      'title': title,
      'titleLower': title.toLowerCase(),
      'description': description,
      'hashtags': hashtags,
      'ownerId': ownerId,
      'rawVideoUrl': rawVideoUrl,
      'rawVideoStoragePath': rawVideoStoragePath,
      'thumbnailUrl': thumbnailUrl,
      'thumbnailStoragePath': thumbnailStoragePath,
      'thumbnailTimeMs': thumbnailTimeMs,
      'durationSeconds': durationSeconds,
      'fileSizeBytes': fileSizeBytes,
      'privacy': privacy,
      'filterUsed': filterUsed,
      'status': 'processing',
      'likesCount': 0,
      'commentsCount': 0,
      'sharesCount': 0,
    };

    payload.removeWhere((_, value) => value == null);
    
    debugPrint('📋 [VideoRepository] Final payload keys: ${payload.keys.toList()}');
    debugPrint('📋 [VideoRepository] Final payload:');
    payload.forEach((key, value) {
      if (key == 'rawVideoUrl') {
        debugPrint('  $key: [URL_REDACTED]');
      } else if (value is List) {
        debugPrint('  $key: List(${value.length})');
      } else {
        debugPrint('  $key: $value');
      }
    });
    
    Get.log('[VideoRepository] Payload keys: ${payload.keys.toList()}');
    Get.log('[VideoRepository] Payload (sanitized): {');
    payload.forEach((key, value) {
      if (key == 'rawVideoUrl') {
        Get.log('  $key: [URL_REDACTED]');
      } else if (value is List) {
        Get.log('  $key: List(${value.length})');
      } else {
        Get.log('  $key: $value');
      }
    });
    Get.log('}');

    try {
      debugPrint('📦 [VideoRepository] Calling createVideoDraft function...');
      final callable = FirebaseFunctions.instance.httpsCallable('createVideoDraft');
      await callable.call(<String, dynamic>{
        'videoId': videoId,
        'data': payload,
      });
      debugPrint('✅ [VideoRepository] createVideoDraft completed successfully');
      Get.log('[VideoRepository] ✓ createVideoDraft completed successfully');
    } catch (e) {
      debugPrint('❌❌❌ [VideoRepository] createVideoDraft FAILED: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      Get.log('[VideoRepository] ✗ createVideoDraft failed: $e', isError: true);
      rethrow;
    }
  }

  /// Search ready videos by title prefix (case-insensitive) and by hashtag exact match.
  /// Returns up to [limit] unique results, deduplicated across strategies.
  ///
  /// Notes on indexing/fallbacks:
  /// - We apply server-side equality filters on `status == 'ready'` and `privacy == 'public'`
  ///   to satisfy Firestore rules before querying titles/hashtags.
  /// - We primarily search the `titleLower` field (added in recent versions).
  ///   For legacy documents that may not have `titleLower`, we include a
  ///   fallback range query on the original `title` field if the first query
  ///   yields zero results.
  Future<List<VideoModel>> searchVideos(
    String query, {
    int limit = 20,
    List<String>? followedUserIds,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    try {
      // Title prefix search using titleLower range query with server-side privacy/status filters
      QuerySnapshot<Map<String, dynamic>> titleSnap = await _firestore
          .collection('videos')
          .where('status', isEqualTo: 'ready')
          .where('privacy', isEqualTo: 'public')
          .where('titleLower', isGreaterThanOrEqualTo: q)
          .where('titleLower', isLessThan: '$q\uf8ff')
          .orderBy('titleLower')
          .limit(limit)
          .get();

      // Fallback: If no hits (e.g., legacy docs missing `titleLower`), try the
      // same range query on the original `title` field.
      if (titleSnap.docs.isEmpty) {
        try {
          titleSnap = await _firestore
              .collection('videos')
              .where('status', isEqualTo: 'ready')
              .where('privacy', isEqualTo: 'public')
              .where('title', isGreaterThanOrEqualTo: query)
              .where('title', isLessThan: '$query\uf8ff')
              .orderBy('title')
              .limit(limit)
              .get();
        } catch (_) {
          // Ignore fallback errors; we'll rely on hashtag results if any.
        }
      }

      // Hashtag exact search using array-contains
      // Normalize hashtag: ensure single leading '#'
      final tag = q.startsWith('#') ? q : '#$q';
      final hashtagSnap = await _firestore
          .collection('videos')
          .where('status', isEqualTo: 'ready')
          .where('privacy', isEqualTo: 'public')
          .where('hashtags', arrayContains: tag)
          .limit(limit)
          .get();

      final seen = <String>{};
      final results = <VideoModel>[];
      for (final d in [...titleSnap.docs, ...hashtagSnap.docs]) {
        final data = d.data();
        if (seen.add(d.id)) {
          results.add(
            VideoModel.fromJson({
              ...data,
              'id': d.id,
            }),
          );
          if (results.length >= limit) break;
        }
      }

      // Always search followers-only videos if we have followed users
      if (followedUserIds != null && followedUserIds.isNotEmpty) {
        final followerMatches = await _searchFollowersOnlyVideos(
          normalizedQuery: q,
          normalizedHashtag: tag,
          followedUserIds: followedUserIds,
          limit: limit, // Request full limit to ensure we get enough candidates
          seen: seen,
        );
        results.addAll(followerMatches);
      }

      // Sort merged results by title to ensure consistent ordering
      results.sort((a, b) {
        final titleA = a.title.toLowerCase();
        final titleB = b.title.toLowerCase();
        return titleA.compareTo(titleB);
      });

      return results.take(limit).toList();
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        Get.log(
          'Missing Firestore index for video search. Ensure indexes for (status, privacy, titleLower) and (status, privacy, hashtags) exist.',
        );
      }
      rethrow;
    }
  }

  /// Compute trending hashtags from recent ready videos (last 7 days).
  /// Returns hashtags ordered by frequency (desc), limited to [limit].
  Future<List<String>> getTrendingHashtags({int limit = 10}) async {
    try {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final snap = await _firestore
          .collection('videos')
          .where('status', isEqualTo: 'ready')
          .where('privacy', isEqualTo: 'public')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
          .orderBy('createdAt', descending: true)
          .limit(500)
          .get();

      final counts = <String, int>{};
      for (final d in snap.docs) {
        final data = d.data();
        final tags = (data['hashtags'] as List?)?.cast<String>() ?? const <String>[];
        for (final raw in tags) {
          final tag = raw.trim();
          if (tag.isEmpty) continue;
          counts[tag] = (counts[tag] ?? 0) + 1;
        }
      }

      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sorted.take(limit).map((e) => e.key).toList();
    } catch (e) {
      Get.log('getTrendingHashtags failed: $e', isError: true);
      return [];
    }
  }

  /// Returns a page of videos for a specific user ordered by createdAt desc.
  /// Expects a `createdAt` field (Timestamp) and `ownerId` on documents.
  Future<VideoPage> getUserVideosPage(
    String userId, {
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    bool isOwnProfile = false,
    bool viewerFollowsOwner = false,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('videos')
          .where('ownerId', isEqualTo: userId)
          .where('status', isEqualTo: 'ready');

      // Privacy filter: only show public videos when viewing other users' profiles
      if (!isOwnProfile) {
        // If the viewer follows the owner, include both public and followers-only videos.
        // Otherwise, only include public videos.
        query = viewerFollowsOwner
            ? query.where('privacy', whereIn: ['public', 'followers-only'])
            : query.where('privacy', isEqualTo: 'public');
      }

      query = query
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snap = await query.get();
      final docs = snap.docs;
      final items = docs
          .map(
            (d) => VideoModel.fromJson({
              // include id
              ...d.data(),
              'id': d.id,
            }),
          )
          .toList();

      final lastDoc = docs.isNotEmpty ? docs.last : null;
      final hasMore = docs.length == limit;
      return VideoPage(items: items, lastDoc: lastDoc, lastCursor: null, hasMore: hasMore);
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        Get.log(
          'Missing Firestore index for user videos feed. Deploy firestore.indexes.json via "firebase deploy --only firestore:indexes".',
        );
        throw Exception(
          'Missing Firestore index for user videos query. Deploy firestore.indexes.json via "firebase deploy --only firestore:indexes".',
        );
      }
      rethrow;
    }
  }

  /// Returns the count of videos visible to the viewer on a profile, respecting privacy.
  Future<int> getUserVisibleVideosCount({
    required String userId,
    required bool isOwnProfile,
    required bool viewerFollowsOwner,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('videos')
          .where('ownerId', isEqualTo: userId)
          .where('status', isEqualTo: 'ready');

      if (!isOwnProfile) {
        query = viewerFollowsOwner
            ? query.where('privacy', whereIn: ['public', 'followers-only'])
            : query.where('privacy', isEqualTo: 'public');
      }

      final countSnap = await query.count().get();
      return countSnap.count ?? 0;
    } catch (e) {
      Get.log('getUserVisibleVideosCount failed: $e', isError: true);
      return 0;
    }
  }

  Future<ToggleLikeResult> toggleLike({
    required String videoId,
    required String userId,
  }) async {
    // If offline, enqueue persisted action and return optimistic result
    final online = Get.find<ConnectivityService>().isOnline.value;
    if (!online) {
      // Enqueue persisted action; controller already applied optimistic UI
      await Get.find<OfflineQueueService>().enqueueAction(
        OfflineAction(
          type: OfflineActionType.videoToggleLike,
          payload: {'videoId': videoId, 'userId': userId},
        ),
      );
      // We cannot know resulting count offline; return current values best-effort
      // Callers should already be optimistic; here we just echo a flip.
      return ToggleLikeResult(isLiked: true, likesCount: 0);
    }

    // Use Firestore transaction to atomically update both like subcollection and video likesCount
    return await _firestore.runTransaction((transaction) async {
      final videoRef = _firestore.collection('videos').doc(videoId);
      final likeRef = videoRef.collection('likes').doc(userId);
      
      // Read current state
      final videoDoc = await transaction.get(videoRef);
      final likeDoc = await transaction.get(likeRef);
      
      // Get current likesCount from video document (default to 0 if not set)
      final currentLikes = videoDoc.data()?['likesCount'] ?? 0;
      
      if (likeDoc.exists) {
        // Unlike: delete like document and decrement counter
        transaction.delete(likeRef);
        transaction.update(videoRef, {
          'likesCount': currentLikes - 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return ToggleLikeResult(isLiked: false, likesCount: currentLikes - 1);
      } else {
        // Like: create like document and increment counter
        transaction.set(likeRef, {
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(videoRef, {
          'likesCount': currentLikes + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return ToggleLikeResult(isLiked: true, likesCount: currentLikes + 1);
      }
    });
  }

  /// Updates thumbnail fields on a video document after the optional thumbnail is uploaded.
  Future<void> updateVideoThumbnail({
    required String videoId,
    required String thumbnailUrl,
    required String thumbnailStoragePath,
    int? thumbnailTimeMs,
  }) async {
    final videoRef = _firestore.collection('videos').doc(videoId);
    final payload = <String, dynamic>{
      'thumbnailUrl': thumbnailUrl,
      'thumbnailStoragePath': thumbnailStoragePath,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (thumbnailTimeMs != null) {
      payload['thumbnailTimeMs'] = thumbnailTimeMs;
    }
    await videoRef.update(payload);
  }

  // Step 8.9: Status checks and listener
  Future<Map<String, dynamic>?> getVideoDocument(String videoId) async {
    final doc = await _firestore.collection('videos').doc(videoId).get();
    return doc.data();
  }

  Stream<Map<String, dynamic>?> watchVideoDocument(String videoId) {
    return _firestore.collection('videos').doc(videoId).snapshots().map((s) => s.data());
  }

  /// Convenience: fetches the ownerId for a given videoId (or empty string if missing).
  Future<String> getVideoOwnerId(String videoId) async {
    final doc = await _firestore.collection('videos').doc(videoId).get();
    if (!doc.exists) return '';
    return (doc.data()?['ownerId'] as String?)?.trim() ?? '';
  }

  /// Real-time top-of-feed stream for public videos.
  Stream<List<VideoModel>> getVideoFeedStream({int limit = 20}) {
    return _publicFeedStreamEntries(limit).map(
      (entries) => entries.take(limit).map((e) => e.video).toList(),
    );
  }

  /// Real-time top-of-feed stream for followers-only videos.
  Stream<List<VideoModel>> getFollowersOnlyFeedStream({int limit = 20}) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value(const <VideoModel>[]);
    }

    return Stream.fromFuture(getFollowingUserIds(currentUserId)).asyncExpand((followedUserIds) {
      if (followedUserIds.isEmpty) {
        return Stream.value(const <VideoModel>[]);
      }

      return _followersFeedStreamEntries(followedUserIds, limit).map(
        (entries) => entries.take(limit).map((e) => e.video).toList(),
      );
    });
  }

  /// Watches a single video document and maps it to VideoModel.
  /// Returns null when the document is missing or unreadable by security rules.
  Stream<VideoModel?> watchVideo(String videoId) {
    return _firestore
        .collection('videos')
        .doc(videoId)
        .snapshots()
        .map((s) {
          final data = s.data();
          if (data == null) return null;
          try {
            return VideoModel.fromJson({
              ...data,
              'id': s.id,
            });
          } catch (_) {
            return null;
          }
        });
  }

  Future<String?> checkVideoStatus(String videoId) async {
    final data = await getVideoDocument(videoId);
    return data?['status'] as String?;
  }

  // Step 8.12: Retry processing via callable function
  Future<void> retryProcessing(String videoId) async {
    final callable = _functions.httpsCallable('retryProcessVideo');
    await callable.call({'videoId': videoId});
    await _analytics.logEvent(name: 'video_processing_retry', parameters: {
      'video_id': videoId,
    });
  }

  // Step 8.14: Analytics helpers
  Future<void> logUploadStarted(String videoId) async {
    await _analytics.logEvent(name: 'video_upload_started', parameters: {
      'video_id': videoId,
    });
  }

  Future<void> logUploadCompleted(String videoId) async {
    await _analytics.logEvent(name: 'video_upload_completed', parameters: {
      'video_id': videoId,
    });
  }

  Future<void> logUploadFailed(String videoId, {String? code}) async {
    await _analytics.logEvent(name: 'video_upload_failed', parameters: {
      'video_id': videoId,
      if (code != null) 'code': code,
    });
  }

  // ===== Admin dashboard helpers =====

  Future<int> getAllVideosCount() async {
    final countSnap = await _firestore.collection('videos').count().get();
    return countSnap.count ?? 0;
  }

  Future<List<VideoModel>> getFlaggedVideos({int limit = 20}) async {
    // Assuming schema has status 'flagged' or a separate 'flagged' boolean
    try {
      final snap = await _firestore
          .collection('videos')
          .where('status', isEqualTo: 'flagged')
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => VideoModel.fromJson({
            ...d.data(),
            'id': d.id,
          })).toList();
    } catch (_) {
      // If status-based flagging not present, fallback to empty list
      return [];
    }
  }

  Future<void> approveVideo(String videoId) async {
    await _firestore.collection('videos').doc(videoId).update({
      'status': 'ready',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeVideo(String videoId) async {
    await _firestore.collection('videos').doc(videoId).update({
      'status': 'removed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, int>> getVideoUploadData(DateTime startDate, DateTime endDate) async {
    final snap = await _firestore
        .collection('videos')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('createdAt')
        .get();
    final map = <String, int>{};
    for (final d in snap.docs) {
      final ts = d.data()['createdAt'] as Timestamp?;
      if (ts == null) continue;
      final date = ts.toDate();
      final key = DateTime(date.year, date.month, date.day).toIso8601String();
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  Future<List<VideoModel>> getTrendingVideos({int limit = 10}) async {
    // Prefer curated trending_videos if available
    try {
      final trendingSnap = await _firestore
          .collection('trending_videos')
          .orderBy('rank')
          .limit(limit)
          .get();
      if (trendingSnap.docs.isNotEmpty) {
        final ids = trendingSnap.docs.map((d) => (d.data()['videoId'] as String)).toList();
        final videos = await getVideosByIds(ids);
        // Preserve rank order
        final byId = {for (final v in videos) v.id: v};
        return ids.map((id) => byId[id]).whereType<VideoModel>().toList();
      }
    } catch (_) {
      // fall back to likesCount order
    }

    try {
      final snap = await _firestore
          .collection('videos')
          .where('status', isEqualTo: 'ready')
          .orderBy('likesCount', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => VideoModel.fromJson({
            ...d.data(),
            'id': d.id,
          })).toList();
    } catch (_) {
      return [];
    }
  }

  // ===== Real-time social helpers =====

  /// Emits the current likes count for a video by listening to the likes subcollection.
  /// Uses query snapshots length; for large scales consider Firestore count() aggregation with polling.
  Stream<int> likesCountStream(String videoId) {
    return _firestore
        .collection('videos')
        .doc(videoId)
        .collection('likes')
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Emits whether the [userId] has liked the [videoId].
  Stream<bool> isLikedStream({required String videoId, required String userId}) {
    return _firestore
        .collection('videos')
        .doc(videoId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Emits the number of comments for a video using top-level `comments` collection filtered by videoId.
  Stream<int> commentsCountStream(String videoId) {
    return _firestore
        .collection('comments')
        .where('videoId', isEqualTo: videoId)
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Toggles saved state by creating/deleting a doc under videos/{videoId}/saves/{userId}.
  Future<bool> toggleSave({required String videoId, required String userId}) async {
    final online = Get.find<ConnectivityService>().isOnline.value;
    if (!online) {
      await Get.find<OfflineQueueService>().enqueueAction(
        OfflineAction(
          type: OfflineActionType.videoToggleSave,
          payload: {'videoId': videoId, 'userId': userId},
        ),
      );
      // Return true as optimistic saved state; controllers already do optimistic set
      return true;
    }
    final saveRef = _firestore.collection('videos').doc(videoId).collection('saves').doc(userId);
    final snap = await saveRef.get();
    if (snap.exists) {
      await saveRef.delete();
      return false;
    } else {
      await saveRef.set({
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    }
  }

  /// Increments the view count for a video.
  /// Called when a user starts watching a video.
  /// Uses FieldValue.increment to atomically update the count.
  Future<void> incrementViewCount(String videoId) async {
    if (videoId.isEmpty) return;
    
    try {
      await _firestore.collection('videos').doc(videoId).update({
        'viewsCount': FieldValue.increment(1),
      });
    } catch (e) {
      // Silent failure - view count is not critical
      Get.log('Failed to increment view count for $videoId: $e');
    }
  }

  /// Emits whether the [userId] has saved/bookmarked the [videoId].
  Stream<bool> isSavedStream({required String videoId, required String userId}) {
    return _firestore
        .collection('videos')
        .doc(videoId)
        .collection('saves')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Returns a stream of liked video IDs for a user using collectionGroup on `likes`.
  Stream<List<String>> likedVideoIdsStream(String userId) {
    Get.log('VideoRepository: creating likedVideoIdsStream for userId=$userId');
    return _firestore
        .collectionGroup('likes')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true) // Match composite index: userId + createdAt
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
          // No need for manual sorting - Firestore returns sorted by createdAt descending
          final ids = snap.docs
              .map((d) => d.reference.parent.parent?.id)
              .whereType<String>()
              .toList();
          Get.log('VideoRepository: likedVideoIdsStream snapshot -> ${ids.length} ids: $ids');
          return ids;
        });
  }

  /// Returns a stream of saved video IDs for a user using collectionGroup on `saves`.
  Stream<List<String>> savedVideoIdsStream(String userId) {
    Get.log('VideoRepository: creating savedVideoIdsStream for userId=$userId');
    return _firestore
        .collectionGroup('saves')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true) // Match composite index: userId + createdAt
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
          // No need for manual sorting - Firestore returns sorted by createdAt descending
          final ids = snap.docs
              .map((d) => d.reference.parent.parent?.id)
              .whereType<String>()
              .toList();
          Get.log('VideoRepository: savedVideoIdsStream snapshot -> ${ids.length} ids: $ids');
          return ids;
        });
  }

  /// Fetches a set of videos by IDs.
  Future<List<VideoModel>> getVideosByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    // Firestore limits 'in' to 10 elements; chunk if needed.
    const chunkSize = 10;
    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += chunkSize) {
      chunks.add(ids.sublist(i, i + chunkSize > ids.length ? ids.length : i + chunkSize));
    }

    final results = <VideoModel>[];
    for (final chunk in chunks) {
      final snap = await _firestore
          .collection('videos')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      results.addAll(snap.docs.map((d) => VideoModel.fromJson({
            ...d.data(),
            'id': d.id,
          })));
    }
    return results;
  }

  /// Generates a signed URL for private/followers-only video access.
  /// 
  /// This method calls the Cloud Function 'generateSignedUrl' to obtain a
  /// time-limited URL for accessing private or followers-only videos.
  /// Public videos return their HLS URL directly without requiring a signed URL.
  /// 
  /// Returns a signed URL that expires after 1 hour for private content.
  /// Throws an exception if the user lacks permission to access the video.
  Future<String> getSignedVideoUrl(String videoId) async {
      try {
        final callable = _functions.httpsCallable('generateSignedUrl');
        final result = await callable.call({'videoId': videoId});
        
        final data = result.data as Map<String, dynamic>;
        final signedUrl = data['signedUrl'] as String;
        
        // Log for debugging (production would use proper logging)
        if (kDebugMode) {
          final expiresAt = data['expiresAt'];
          if (expiresAt != null) {
            final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiresAt as int);
            Get.log('VideoRepository: Signed URL generated for video $videoId, expires at $expiryDate');
          } else {
            Get.log('VideoRepository: Public video $videoId - using direct URL');
          }
        }
        
        return signedUrl;
      } on FirebaseFunctionsException catch (e) {
        // Surface Cloud Function details in logs for better diagnostics
        Get.log(
          'VideoRepository: generateSignedUrl failed for video $videoId - '
          'code=${e.code}, message=${e.message}, details=${e.details}',
          isError: true,
        );
        rethrow;
      } catch (e) {
        Get.log('VideoRepository: Failed to get signed URL for video $videoId: $e', isError: true);
        rethrow;
      }
    }

  /// Deletes a video from Firestore
  /// Note: Storage cleanup is handled by Cloud Functions
  Future<void> deleteVideo(String videoId) async {
    try {
      Get.log('VideoRepository: Deleting video $videoId');
      
      // Delete the video document from Firestore
      await _firestore.collection('videos').doc(videoId).delete();
      
      // Invalidate cache
      _cacheService.invalidateVideo(videoId);
      
      Get.log('VideoRepository: Successfully deleted video $videoId');
    } catch (e, stackTrace) {
      Get.log('VideoRepository: Failed to delete video $videoId: $e', isError: true);
      Get.log('Stack trace: $stackTrace', isError: true);
      rethrow;
    }
  }

  /// Flags a video as inappropriate for admin moderation
  /// Updates video status to 'flagged' and records flagging metadata
  Future<void> flagVideo(String videoId) async {
    try {
      // Get current user ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to flag videos');
      }

      Get.log('VideoRepository: Flagging video $videoId by user ${user.uid}');
      
      // Call Cloud Function for server-side rate limiting
      final callable = _functions.httpsCallable('flagVideo');
      final result = await callable.call({'videoId': videoId});
      
      final data = result.data as Map<String, dynamic>;
      final success = data['success'] as bool;
      final message = data['message'] as String;
      
      if (!success) {
        throw Exception(message);
      }
      
      // Invalidate cache since video status changed
      _cacheService.invalidateVideo(videoId);
      
      // Log analytics event
      if (!Get.testMode) {
        await _analytics.logEvent(
          name: 'video_flagged',
          parameters: {
            'video_id': videoId,
            'user_id': user.uid,
          },
        );
      }
      
      Get.log('VideoRepository: Successfully flagged video $videoId');
    } catch (e, stackTrace) {
      Get.log('VideoRepository: Failed to flag video $videoId: $e', isError: true);
      Get.log('Stack trace: $stackTrace', isError: true);
      rethrow;
    }
  }
}
