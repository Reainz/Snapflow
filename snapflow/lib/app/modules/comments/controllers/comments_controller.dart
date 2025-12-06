import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../data/models/comment_model.dart';
import '../../../data/repositories/comments_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../../data/repositories/video_repository.dart';
// Offline queuing is handled in repositories; controller stays agnostic

class CommentsController extends GetxController {
  final CommentsRepository _repo = Get.put(CommentsRepository());
  final UserRepository _userRepository = Get.find<UserRepository>();
  final AuthService _auth = Get.find<AuthService>();
  final NotificationRepository _notificationRepository = Get.find<NotificationRepository>();
  final VideoRepository _videoRepository = Get.find<VideoRepository>();

  final comments = <CommentModel>[].obs;
  final isSending = false.obs;
  final isLoading = true.obs;  // NEW: Loading state
  final videoId = ''.obs;
  final showEmojiPicker = false.obs;  // NEW: Emoji picker state

  // Maps to track like states and counts for each comment
  final commentLikedStates = <String, RxBool>{}.obs;
  final commentLikeCounts = <String, RxInt>{}.obs;
  final _likeSubscriptions = <String, StreamSubscription>{};
  
  // NEW: Username cache to avoid redundant fetches
  final _usernameCache = <String, String>{};

  StreamSubscription? _sub;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map && args['videoId'] is String) {
      videoId.value = args['videoId'] as String;
      isLoading.value = true;  // Start loading
      _sub = _repo.watchComments(videoId.value).listen((newComments) {
        comments.assignAll(newComments);
        isLoading.value = false;  // Stop loading once data arrives
        // Setup streams for each comment's like state
        _setupLikeStreams(newComments);
      });
    }
  }

  void _setupLikeStreams(List<CommentModel> newComments) {
    final user = _auth.currentUser.value;
    if (user == null) return;

    // Cancel streams for removed comments
    final currentIds = newComments.map((c) => c.id).toSet();
    final keysToRemove = _likeSubscriptions.keys.where((key) {
      // Extract comment ID from subscription key (e.g., "commentId_liked" or "commentId_count")
      final parts = key.split('_');
      if (parts.isEmpty) return false;
      // Remove the last part (_liked or _count) to get the comment ID
      final commentId = parts.length > 1 ? parts.sublist(0, parts.length - 1).join('_') : parts[0];
      return !currentIds.contains(commentId);
    }).toList();
    
    for (final key in keysToRemove) {
      _likeSubscriptions[key]?.cancel();
      _likeSubscriptions.remove(key);
    }
    
    // Remove reactive states for removed comments
    final stateKeysToRemove = commentLikedStates.keys.where((id) => !currentIds.contains(id)).toList();
    for (final id in stateKeysToRemove) {
      commentLikedStates.remove(id);
      commentLikeCounts.remove(id);
    }

    // Setup streams for new comments
    for (final comment in newComments) {
      final likedKey = '${comment.id}_liked';
      final countKey = '${comment.id}_count';
      
      // Only setup if not already subscribed
      if (!_likeSubscriptions.containsKey(likedKey)) {
        // Initialize reactive variables if they don't exist
        if (!commentLikedStates.containsKey(comment.id)) {
          commentLikedStates[comment.id] = false.obs;
        }
        if (!commentLikeCounts.containsKey(comment.id)) {
          commentLikeCounts[comment.id] = 0.obs;
        }

        // Setup liked state stream
        _likeSubscriptions[likedKey] = _repo
            .isCommentLikedStream(commentId: comment.id, userId: user.uid)
            .listen((isLiked) {
          commentLikedStates[comment.id]?.value = isLiked;
        });

        // Setup like count stream
        _likeSubscriptions[countKey] = _repo
            .commentLikesCountStream(comment.id)
            .listen((count) {
          commentLikeCounts[comment.id]?.value = count;
        });
      }
    }
  }

  Future<void> sendComment(String text) async {
    if (text.trim().isEmpty || videoId.value.isEmpty) return;
    final user = _auth.currentUser.value;
    if (user == null) return;
    try {
      isSending.value = true;
      await _repo.addComment(videoId: videoId.value, authorId: user.uid, text: text.trim());

      // Create a notification for video owner
      try {
        final ownerId = await _videoRepository.getVideoOwnerId(videoId.value);
        if (ownerId.isNotEmpty && ownerId != user.uid) {
          String? actorName;
          try {
            final actorUser = await _userRepository.getUserById(user.uid);
            actorName = (actorUser.displayName.isNotEmpty
                    ? actorUser.displayName
                    : actorUser.username)
                .trim();
          } catch (_) {}
          await _notificationRepository.createNotification(
            recipientUserId: ownerId,
            type: AppNotificationType.comment,
            actorUserId: user.uid,
            videoId: videoId.value,
            actorDisplayName: actorName,
            title: 'New Comment',
            payload: {'route': 'comments', 'videoId': videoId.value},
          );
        }
      } catch (_) {}
    } finally {
      isSending.value = false;
    }
  }

  Future<void> toggleLike(String commentId) async {
    final user = _auth.currentUser.value;
    if (user == null) return;
    try {
      final liked = await _repo.toggleCommentLike(
        commentId: commentId,
        userId: user.uid,
      );

      // If the result is a new like, send a notification to the comment author
      if (liked) {
        CommentModel? target;
        for (final c in comments) {
          if (c.id == commentId) {
            target = c;
            break;
          }
        }
        if (target != null &&
            target.authorId.isNotEmpty &&
            target.authorId != user.uid) {
          String? actorName;
          try {
            final actorUser = await _userRepository.getUserById(user.uid);
            actorName = (actorUser.displayName.isNotEmpty
                    ? actorUser.displayName
                    : actorUser.username)
                .trim();
          } catch (_) {}
          try {
            await _notificationRepository.createNotification(
              recipientUserId: target.authorId,
              type: AppNotificationType.like,
              actorUserId: user.uid,
              videoId: target.videoId,
              commentId: target.id,
              actorDisplayName: actorName,
              title: 'New Like',
              payload: {
                'route': 'comments',
                'videoId': target.videoId,
              },
            );
          } catch (_) {
            // Notifications are best-effort; ignore failures here.
          }
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to like comment',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      await _repo.deleteComment(commentId);
      Get.snackbar(
        'Success',
        'Comment deleted',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete comment',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> editComment(String commentId, String newText) async {
    if (newText.trim().isEmpty) return;

    try {
      await _repo.updateComment(commentId: commentId, text: newText.trim());
      Get.snackbar(
        'Success',
        'Comment updated',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update comment',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void showEditDialog(CommentModel comment) {
    final textController = TextEditingController(text: comment.text);
    Get.dialog(
      AlertDialog(
        title: const Text('Edit Comment'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter your comment...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newText = textController.text.trim();
              if (newText.isNotEmpty && newText != comment.text) {
                editComment(comment.id, newText);
              }
              Get.back();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  bool isOwnComment(String authorId) {
    final user = _auth.currentUser.value;
    return user != null && user.uid == authorId;
  }
  
  // NEW: Get cached username or fetch it
  Future<String> getUsernameForComment(String userId) async {
    if (_usernameCache.containsKey(userId)) {
      return _usernameCache[userId]!;
    }
    
    try {
      final user = await _userRepository.getUserById(userId);
      _usernameCache[userId] = user.username;
      return user.username;
    } catch (e) {
      _usernameCache[userId] = 'Unknown User';
      return 'Unknown User';
    }
  }
  
  // NEW: Toggle emoji picker
  void toggleEmojiPicker() {
    showEmojiPicker.value = !showEmojiPicker.value;
  }
  
  // NEW: Hide emoji picker
  void hideEmojiPicker() {
    showEmojiPicker.value = false;
  }

  @override
  void onClose() {
    _sub?.cancel();
    for (final sub in _likeSubscriptions.values) {
      sub.cancel();
    }
    _likeSubscriptions.clear();
    super.onClose();
  }
}
