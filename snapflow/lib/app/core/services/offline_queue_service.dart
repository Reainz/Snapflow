import 'dart:async';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../data/repositories/video_repository.dart';
import '../../data/repositories/comments_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'connectivity_service.dart';

/// Types of persisted offline actions supported by the queue
enum OfflineActionType {
  videoToggleLike,
  videoToggleSave,
  commentToggleLike,
  userToggleFollow,
}

/// A serializable descriptor for an offline action that can survive app restarts
class OfflineAction {
  OfflineAction({required this.type, required this.payload, int? createdAt})
      : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  final OfflineActionType type;
  final Map<String, dynamic> payload;
  final int createdAt;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'payload': payload,
        'createdAt': createdAt,
      };

  static OfflineAction fromJson(Map<String, dynamic> json) {
    final typeName = (json['type'] as String?) ?? '';
    final matched = OfflineActionType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => OfflineActionType.videoToggleLike,
    );
    return OfflineAction(
      type: matched,
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
      createdAt: (json['createdAt'] as num?)?.toInt(),
    );
  }
}

/// Offline queue with both ephemeral (in-memory) and persisted actions.
/// Persisted actions are stored using GetStorage to survive restarts.
class OfflineQueueService extends GetxService {
  // Backwards-compatible ephemeral queue used by legacy callers
  final _ephemeralQueue = <Future<void> Function()>[];

  // Persisted queue
  final _persisted = <OfflineAction>[];
  final isProcessing = false.obs;
  StreamSubscription? _connSub;

  static const _storageKey = 'offline_queue_v1';
  GetStorage? _box; // lazily obtained to avoid early init race

  bool get _online => Get.find<ConnectivityService>().isOnline.value;

  @override
  void onInit() {
    super.onInit();
    // Attempt lazy box acquisition and load persisted actions; if GetStorage isn't
    // ready yet, this will be retried on first enqueueAction() or resume().
    _tryLoadPersisted();

    if (_online) {
      _processAll();
    }
    _connSub = Get.find<ConnectivityService>().isOnline.listen((online) {
      if (online) _processAll();
    });
  }

  /// Call from main after GetStorage.init() to ensure persisted actions are loaded
  Future<void> resume() async {
    await _tryLoadPersisted();
    if (_online) {
      await _processAll();
    }
  }

  // Legacy API: enqueue an ephemeral closure (not persisted)
  void enqueue(Future<void> Function() task) {
    _ephemeralQueue.add(task);
    if (_online) {
      _processEphemeral();
    }
  }

  // New API: enqueue a persisted action that survives restarts
  Future<void> enqueueAction(OfflineAction action) async {
    await _ensureBox();
    _persisted.add(action);
    await _savePersisted();
    if (_online) {
      await _processPersisted();
    }
  }

  Future<void> _processAll() async {
    if (isProcessing.value) return;
    isProcessing.value = true;
    try {
      await _processEphemeral();
      await _processPersisted();
    } finally {
      isProcessing.value = false;
    }
  }

  Future<void> _processEphemeral() async {
    while (_online && _ephemeralQueue.isNotEmpty) {
      final task = _ephemeralQueue.removeAt(0);
      try {
        await task();
      } catch (e) {
        if (Get.isLogEnable) Get.log('OfflineQueue ephemeral task failed: $e', isError: true);
        // Drop the task and continue (legacy behavior)
      }
    }
  }

  Future<void> _processPersisted() async {
    // Process at most N actions per tick to avoid long blocks; here we process all safely
    var progressed = true;
    while (_online && progressed && _persisted.isNotEmpty) {
      progressed = false;
      final action = _persisted.first;
      try {
        await _execute(action);
        _persisted.removeAt(0);
        await _savePersisted();
        progressed = true;
      } catch (e) {
        // Keep the action for a later retry and break the loop to avoid tight retry
        if (Get.isLogEnable) Get.log('OfflineQueue persisted action failed: $e', isError: true);
        break;
      }
    }
  }

  Future<void> _execute(OfflineAction action) async {
    switch (action.type) {
      case OfflineActionType.videoToggleLike:
        {
          final repo = Get.find<VideoRepository>();
          final videoId = action.payload['videoId'] as String? ?? '';
          final userId = action.payload['userId'] as String? ?? '';
          if (videoId.isEmpty || userId.isEmpty) return;
          await repo.toggleLike(videoId: videoId, userId: userId);
          return;
        }
      case OfflineActionType.videoToggleSave:
        {
          final repo = Get.find<VideoRepository>();
          final videoId = action.payload['videoId'] as String? ?? '';
          final userId = action.payload['userId'] as String? ?? '';
          if (videoId.isEmpty || userId.isEmpty) return;
          await repo.toggleSave(videoId: videoId, userId: userId);
          return;
        }
      case OfflineActionType.commentToggleLike:
        {
          final repo = Get.find<CommentsRepository>();
          final commentId = action.payload['commentId'] as String? ?? '';
          final userId = action.payload['userId'] as String? ?? '';
          if (commentId.isEmpty || userId.isEmpty) return;
          await repo.toggleCommentLike(commentId: commentId, userId: userId);
          return;
        }
      case OfflineActionType.userToggleFollow:
        {
          final repo = Get.find<UserRepository>();
          final currentUserId = action.payload['currentUserId'] as String? ?? '';
          final targetUserId = action.payload['targetUserId'] as String? ?? '';
          if (currentUserId.isEmpty || targetUserId.isEmpty) return;
          await repo.toggleFollow(currentUserId, targetUserId);
          // Following feed relies on cached following IDs; invalidate after offline follow/unfollow replays.
          if (Get.isRegistered<VideoRepository>()) {
            Get.find<VideoRepository>().invalidateFollowingCache(currentUserId);
          }
          return;
        }
    }
  }

  Future<void> _ensureBox() async {
    _box ??= Get.isRegistered<GetStorage>() ? Get.find<GetStorage>() : GetStorage();
  }

  Future<void> _tryLoadPersisted() async {
    try {
      await _ensureBox();
      final raw = _box?.read<List>(_storageKey);
      if (raw != null) {
        _persisted
          ..clear()
          ..addAll(raw.whereType<Map>().map((e) => OfflineAction.fromJson(Map<String, dynamic>.from(e))));
      }
    } catch (_) {
      // GetStorage not ready yet or corrupt data; we'll retry later via resume()
    }
  }

  Future<void> _savePersisted() async {
    try {
      await _ensureBox();
      await _box?.write(_storageKey, _persisted.map((e) => e.toJson()).toList());
    } catch (e) {
      if (Get.isLogEnable) Get.log('Failed saving persisted offline queue: $e', isError: true);
    }
  }

  @override
  void onClose() {
    _connSub?.cancel();
    super.onClose();
  }
}
