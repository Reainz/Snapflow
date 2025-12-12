import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/social_service.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/video_model.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/video_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/services/error_service.dart';
import '../../../core/services/video_feed_cache_service.dart';
import '../../followers_feed/controllers/followers_feed_controller.dart';
import '../../video_feed/controllers/video_feed_controller.dart';

class ProfileController extends GetxController {
  final UserRepository _userRepository = Get.find<UserRepository>();
  final AuthService _authService = Get.find<AuthService>();
  final VideoRepository _videoRepository = Get.find<VideoRepository>();
  final SocialService _socialService = Get.find<SocialService>();
  final ImagePicker _imagePicker = ImagePicker();

  final user = Rx<UserModel>(UserModel.empty());
  final userVideos = <VideoModel>[].obs;
  final followers = <UserModel>[].obs; // Placeholder for future implementation
  final following = <UserModel>[].obs; // Placeholder for future implementation

  final isLoading = false.obs;
  final isOwnProfile = false.obs;
  final isLoadingVideos = false.obs;
  final hasMoreVideos = true.obs;
  final isEditLoading = false.obs;
  final isUploadingAvatar = false.obs;
  final uploadProgress = 0.0.obs; // 0.0 - 1.0
  final isFollowing = false.obs;
  final isToggleFollowLoading = false.obs;
  final visibleVideosCount = 0.obs;
  // Liked/Saved videos
  final likedVideos = <VideoModel>[].obs;
  final savedVideos = <VideoModel>[].obs;

  DocumentSnapshot<Map<String, dynamic>>? _lastVideoDoc;
  StreamSubscription<UserModel?>? _userStreamSubscription;
  StreamSubscription<List<String>>? _likedIdsSub;
  StreamSubscription<List<String>>? _savedIdsSub;
  // Per-video realtime subscriptions keyed by videoId
  final Map<String, StreamSubscription<VideoModel?>> _likedVideoSubs = {};
  final Map<String, StreamSubscription<VideoModel?>> _savedVideoSubs = {};
  // Keep last emitted id order to render grids deterministically
  List<String> _likedOrder = const [];
  List<String> _savedOrder = const [];
  // Active caches for liked/saved video documents. Kept at controller scope
  // to ensure there is only one authoritative cache at any time. This avoids
  // old closures (from previous subscriptions) mutating a stale local map.
  final Map<String, VideoModel?> _likedCache = {};
  final Map<String, VideoModel?> _savedCache = {};

  late String targetUserId;
  // Remember the last route-argument userId we applied in the view to avoid
  // re-applying it after we intentionally switch profiles within the same route.
  String? routeArgLastAppliedUserId;

  /// Call when a route argument has been consumed so it won't be re-applied
  /// on subsequent builds unless the arg actually changes.
  void markRouteArgApplied(String userId) {
    routeArgLastAppliedUserId = userId;
    // Lightweight debug trace to help diagnose intermittent routing issues
    if (LogConfig.verbose) {
      Get.log('ProfileController: route arg applied -> $userId');
    }
  }

  @override
  void onInit() {
    super.onInit();
    // Accept either Get.parameters['userId'] or Get.arguments map
    final paramsId = Get.parameters['userId'];
    final args = Get.arguments;
    String? argUserId;
    if (args is Map && args['userId'] is String) {
      argUserId = args['userId'] as String;
    }
    final currentUid = _authService.currentUser.value?.uid;
    targetUserId = (paramsId ?? argUserId ?? currentUid ?? '').trim();
    if (targetUserId.isEmpty && currentUid != null) {
      targetUserId = currentUid;
    }

    Get.log(
      'ProfileController.onInit: targetUserId=$targetUserId, currentUid=$currentUid',
    );

    // Defer initial load slightly to ensure AuthService currentUser is set
    Future.microtask(_loadInitial);
  }

  Future<void> _loadInitial() async {
    Get.log(
      'ProfileController._loadInitial called: targetUserId=$targetUserId, isEmpty=${targetUserId.isEmpty}',
    );
    if (targetUserId.isEmpty) {
      Get.log(
        'ProfileController._loadInitial: targetUserId is empty, returning early',
        isError: true,
      );
      return;
    }
    Get.log('ProfileController._loadInitial: about to load user profile');
    await loadUserProfile(targetUserId);
    Get.log(
      'ProfileController._loadInitial: user profile loaded, about to load videos',
    );
    await loadUserVideos(targetUserId, reset: true);
    unawaited(_updateVisibleVideosCount());
    Get.log(
      'ProfileController._loadInitial: videos loaded, setting up realtime updates',
    );
    _setupRealtimeProfileUpdates();
    Get.log(
      'ProfileController._loadInitial: about to call _subscribeLikedSaved($targetUserId)',
    );
    // Always subscribe to liked/saved videos for ANY user we're viewing
    _subscribeLikedSaved(targetUserId);
    Get.log(
      'ProfileController._loadInitial: _subscribeLikedSaved called successfully',
    );

    if (LogConfig.verbose) {
      Get.log(
        'ProfileController: loaded initial profile for $targetUserId (isOwn: ${isOwnProfile.value})',
      );
    }
  }

  void _setupRealtimeProfileUpdates() {
    if (targetUserId.isEmpty) return;

    _userStreamSubscription?.cancel(); // Cancel any existing subscription
    _userStreamSubscription = _userRepository
        .getUserStream(targetUserId)
        .listen(
          (updatedUser) {
            if (updatedUser != null) {
              user.value = updatedUser;
              final currentUid = _authService.currentUser.value?.uid;
              isOwnProfile.value =
                  currentUid != null && currentUid == targetUserId;

              // Check if current user is following this profile
              if (currentUid != null && currentUid != targetUserId) {
                _checkFollowStatus(currentUid, targetUserId);
              }
            }
          },
          onError: (error) {
            // Log error for debugging but don't show to user
            // In production, this would integrate with crashlytics/logging service
            Get.snackbar(
              'Connection Error',
              'Unable to sync profile updates',
              snackPosition: SnackPosition.BOTTOM,
              duration: const Duration(seconds: 2),
            );
          },
        );
  }

  Future<void> _checkFollowStatus(
    String currentUserId,
    String targetUserId,
  ) async {
    try {
      final following = await _userRepository.isFollowing(
        currentUserId,
        targetUserId,
      );
      isFollowing.value = following;
      unawaited(_updateVisibleVideosCount());
    } catch (e) {
      // Silently handle follow status check errors
      // In production, this would integrate with logging service
      isFollowing.value = false; // Default to not following on error
    }
  }

  Future<void> _updateVisibleVideosCount() async {
    if (targetUserId.isEmpty) return;
    try {
      final count = await _videoRepository.getUserVisibleVideosCount(
        userId: targetUserId,
        isOwnProfile: isOwnProfile.value,
        viewerFollowsOwner: isFollowing.value,
      );
      visibleVideosCount.value = count;
    } catch (e) {
      if (LogConfig.verbose) {
        Get.log('Failed to update visibleVideosCount: $e', isError: true);
      }
    }
  }

  Future<void> loadUserProfile(String userId) async {
    try {
      isLoading.value = true;
      final profile = await _userRepository.getUserById(userId);
      user.value = profile;
      final currentUid = _authService.currentUser.value?.uid;
      isOwnProfile.value = currentUid != null && currentUid == userId;
    } catch (e) {
      Get.snackbar('Error', 'Failed to load profile: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshProfile() async {
    if (targetUserId.isEmpty) return;
    await loadUserProfile(targetUserId);
    await loadUserVideos(targetUserId, reset: true);
  }

  /// Switches the controller to display a different user's profile.
  /// Re-initializes streams and reloads videos for the new target user.
  Future<void> openUser(String newUserId) async {
    Get.log(
      'ProfileController.openUser called: newUserId=$newUserId, currentTargetUserId=$targetUserId',
    );
    final trimmed = newUserId.trim();
    if (trimmed.isEmpty) {
      Get.log(
        'ProfileController.openUser: newUserId is empty, returning',
        isError: true,
      );
      return;
    }
    if (trimmed == targetUserId && user.value.id.isNotEmpty) {
      // Already showing this user; still ensure stream is active
      Get.log(
        'ProfileController.openUser: already showing user $trimmed, ensuring realtime updates',
      );
      _setupRealtimeProfileUpdates();
      return;
    }
    Get.log('ProfileController: openUser -> $trimmed (from $targetUserId)');
    targetUserId = trimmed;
    Get.log('ProfileController.openUser: loading new user profile $trimmed');

    // Cancel ALL subscriptions including per-video streams
    _userStreamSubscription?.cancel();
    _likedIdsSub?.cancel();
    _savedIdsSub?.cancel();

    // CRITICAL FIX: Cancel per-video subscriptions and clear caches
    for (final s in _likedVideoSubs.values) {
      s.cancel();
    }
    for (final s in _savedVideoSubs.values) {
      s.cancel();
    }
    _likedVideoSubs.clear();
    _savedVideoSubs.clear();
    _likedCache.clear();
    _savedCache.clear();

    likedVideos.clear();
    savedVideos.clear();
    await loadUserProfile(targetUserId);
    await loadUserVideos(targetUserId, reset: true);
    _setupRealtimeProfileUpdates();
    Get.log(
      'ProfileController.openUser: calling _subscribeLikedSaved for uid=$targetUserId',
    );
    _subscribeLikedSaved(targetUserId);
  }

  Future<void> loadUserVideos(String userId, {bool reset = false}) async {
    if (isLoadingVideos.value) return;
    if (reset) {
      _lastVideoDoc = null;
      hasMoreVideos.value = true;
      userVideos.clear();
      visibleVideosCount.value = 0;
    }
    if (!hasMoreVideos.value) return;
    try {
      isLoadingVideos.value = true;
      final page = await _videoRepository.getUserVideosPage(
        userId,
        limit: 20,
        startAfter: _lastVideoDoc,
        isOwnProfile:
            isOwnProfile.value, // Pass isOwnProfile flag for privacy filtering
        viewerFollowsOwner: isFollowing.value, // Pass follower relationship for followers-only videos
      );
      userVideos.addAll(page.items);
      _lastVideoDoc = page.lastDoc;
      hasMoreVideos.value = page.hasMore;
    } catch (e) {
      Get.snackbar('Error', 'Failed to load videos: ${e.toString()}');
    } finally {
      isLoadingVideos.value = false;
    }
  }

  // Helper methods for rebuilding liked/saved video lists
  void _rebuildLiked(Map<String, VideoModel?> cache) {
    final list = <VideoModel>[];
    for (final id in _likedOrder) {
      final v = cache[id];
      if (v != null) list.add(v);
    }
    likedVideos.assignAll(list);
    Get.log(
      'ProfileController: updated likedVideos observable with ${list.length} videos',
    );
  }

  void _rebuildSaved(Map<String, VideoModel?> cache) {
    final list = <VideoModel>[];
    for (final id in _savedOrder) {
      final v = cache[id];
      if (v != null) list.add(v);
    }
    savedVideos.assignAll(list);
    Get.log(
      'ProfileController: updated savedVideos observable with ${list.length} videos',
    );
  }

  void _subscribeLikedSaved(String uid) {
    try {
      Get.log(
        'ProfileController._subscribeLikedSaved: ENTRY - uid=$uid, isEmpty=${uid.isEmpty}',
      );

      if (uid.isEmpty) {
        Get.log(
          'ProfileController._subscribeLikedSaved: uid is empty, returning early',
          isError: true,
        );
        return;
      }

      Get.log('ProfileController: subscribing to liked/saved for uid=$uid');

      // Cancel previous ID streams
      Get.log('ProfileController: cancelling previous subscriptions');
      _likedIdsSub?.cancel();
      _savedIdsSub?.cancel();

      // Cancel and clear any per-video subscriptions from a prior user/context
      for (final s in _likedVideoSubs.values) {
        s.cancel();
      }
      for (final s in _savedVideoSubs.values) {
        s.cancel();
      }
      _likedVideoSubs.clear();
      _savedVideoSubs.clear();

      // Reset state and caches so UI doesn't display stale data during switch
      Get.log('ProfileController: resetting state and caches');
      _likedOrder = const [];
      _savedOrder = const [];
      _likedCache.clear();
      _savedCache.clear();
      likedVideos.clear();
      savedVideos.clear();

      Get.log(
        'ProfileController: _subscribeLikedSaved reset complete, starting new subscriptions for uid=$uid',
      );

      _likedIdsSub = _videoRepository
          .likedVideoIdsStream(uid)
          .listen(
            (ids) {
              Get.log(
                'ProfileController: likedVideoIdsStream emitted ${ids.length} ids: $ids',
              );
              // Unsubscribe removed ids
              for (final entry in _likedVideoSubs.entries.toList()) {
                if (!ids.contains(entry.key)) {
                  Get.log(
                    'ProfileController: cancelling liked video sub for removed id=${entry.key}',
                  );
                  entry.value.cancel();
                  _likedVideoSubs.remove(entry.key);
                  _likedCache.remove(entry.key);
                }
              }
              _likedOrder = List<String>.from(ids);
              // Subscribe new ids
              for (final id in ids) {
                if (_likedVideoSubs.containsKey(id)) continue;
                Get.log(
                  'ProfileController: subscribing to watchVideo for new liked id=$id',
                );
                _likedVideoSubs[id] = _videoRepository
                    .watchVideo(id)
                    .listen(
                      (video) {
                        Get.log(
                          'ProfileController: watchVideo emitted for liked id=$id, video=${video?.id ?? "null"}',
                        );
                        _likedCache[id] =
                            video; // null when deleted or inaccessible
                        _rebuildLiked(_likedCache);
                      },
                      onError: (e) {
                        Get.log(
                          'ProfileController: watchVideo error for liked id=$id -> $e',
                          isError: true,
                        );
                      },
                    );
              }
              // Initial rebuild (for cases where cache holds some data already)
              _rebuildLiked(_likedCache);
            },
            onError: (e) {
              Get.log(
                'ProfileController: likedVideoIdsStream error: $e',
                isError: true,
              );
            },
          );

      _savedIdsSub = _videoRepository
          .savedVideoIdsStream(uid)
          .listen(
            (ids) {
              Get.log(
                'ProfileController: savedVideoIdsStream emitted ${ids.length} ids: $ids',
              );
              for (final entry in _savedVideoSubs.entries.toList()) {
                if (!ids.contains(entry.key)) {
                  Get.log(
                    'ProfileController: cancelling saved video sub for removed id=${entry.key}',
                  );
                  entry.value.cancel();
                  _savedVideoSubs.remove(entry.key);
                  _savedCache.remove(entry.key);
                }
              }
              _savedOrder = List<String>.from(ids);
              for (final id in ids) {
                if (_savedVideoSubs.containsKey(id)) continue;
                Get.log(
                  'ProfileController: subscribing to watchVideo for new saved id=$id',
                );
                _savedVideoSubs[id] = _videoRepository
                    .watchVideo(id)
                    .listen(
                      (video) {
                        Get.log(
                          'ProfileController: watchVideo emitted for saved id=$id, video=${video?.id ?? "null"}',
                        );
                        _savedCache[id] = video;
                        _rebuildSaved(_savedCache);
                      },
                      onError: (e) {
                        Get.log(
                          'ProfileController: watchVideo error for saved id=$id -> $e',
                          isError: true,
                        );
                      },
                    );
              }
              _rebuildSaved(_savedCache);
            },
            onError: (e) {
              Get.log(
                'ProfileController: savedVideoIdsStream error: $e',
                isError: true,
              );
            },
          );

      Get.log(
        'ProfileController._subscribeLikedSaved: EXIT - subscriptions setup complete',
      );
    } catch (e, stackTrace) {
      Get.log(
        'ProfileController._subscribeLikedSaved: EXCEPTION CAUGHT - $e',
        isError: true,
      );
      Get.log(
        'ProfileController._subscribeLikedSaved: STACK TRACE - $stackTrace',
        isError: true,
      );
    }
  }

  // Sub-step 5.9: Edit Profile Methods
    Future<XFile?> pickProfileImage() async {
      try {
        return await _imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image: ${e.toString()}');
      return null;
    }
    }
  
  Future<String?> uploadProfileImage(XFile imageFile) async {
    try {
      final currentUserId = _authService.currentUser.value?.uid;
      if (currentUserId == null) return null;

      // Quick guard on original file size (helpful for very large camera images)
      try {
        final file = File(imageFile.path);
        final bytes = await file.length();
        if (bytes > 20 * 1024 * 1024) {
          Get.snackbar('Error', 'Image too large (max ~20 MB before compression)');
          return null;
        }
      } catch (_) {}

      isUploadingAvatar.value = true;
      uploadProgress.value = 0.0;

      // Compress to JPEG to ensure a small, rule-compliant avatar file
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.path,
        minWidth: 1024,
        minHeight: 1024,
        quality: 85,
        format: CompressFormat.jpeg,
      );

      if (compressedBytes == null || compressedBytes.isEmpty) {
        Get.snackbar('Error', 'Failed to process image before upload');
        return null;
      }

      if (compressedBytes.length > 5 * 1024 * 1024) {
        Get.snackbar('Error', 'Image too large (max 5 MB after compression)');
        return null;
      }

      // Store avatars as profile-pictures/{userId}.jpg (matches storage.rules + docs)
      final fileName = '$currentUserId.jpg';
      if (LogConfig.verbose) {
        Get.log(
          'Uploading avatar: profile-pictures/$fileName (bytes=${compressedBytes.length}) uid=$currentUserId',
        );
      }

      final ref = FirebaseStorage.instance
          .ref()
          .child('profile-pictures')
          .child(fileName);

      final uploadTask = ref.putData(
        compressedBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=86400', // 1 day cache
        ),
      );

      final sub = uploadTask.snapshotEvents.listen((snapshot) {
        final total = snapshot.totalBytes;
        final transferred = snapshot.bytesTransferred;
        if (total > 0) {
          uploadProgress.value = transferred / total;
        }
      });

      final taskSnapshot = await uploadTask;
      await sub.cancel();

      final url = await taskSnapshot.ref.getDownloadURL();
      uploadProgress.value = 1.0;
      return url;
    } on FirebaseException catch (e) {
      Get.log(
        'Avatar upload failed: code=${e.code}, message=${e.message}, full=$e',
        isError: true,
      );
      Get.snackbar(
        'Error',
        'Upload denied (${e.code}): ${e.message ?? e.toString()}',
      );
      return null;
    } catch (e) {
      Get.log('Avatar upload failed (non-Firebase): $e', isError: true);
      Get.snackbar('Error', 'Failed to upload image: ${e.toString()}');
      return null;
    } finally {
      isUploadingAvatar.value = false;
      // slight delay so user can perceive full progress before reset
      Future.delayed(const Duration(milliseconds: 150), () {
        uploadProgress.value = 0.0;
      });
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    String? website,
    String? location,
    String? avatarUrl,
  }) async {
    try {
      isEditLoading.value = true;
      final currentUserId = _authService.currentUser.value?.uid;
      if (currentUserId == null) return;

      final updates = <String, dynamic>{};
      final bool avatarWillChange =
          avatarUrl != null && avatarUrl != user.value.avatarUrl;
      if (displayName != null) {
        updates['displayName'] = displayName;
        updates['displayNameLower'] = displayName.toLowerCase();
      }
      if (username != null && username.trim().isNotEmpty) {
        final u = username.trim().toLowerCase();
        updates['username'] = u;
      }
      if (bio != null) updates['bio'] = bio;
      if (website != null) updates['website'] = website;
      if (location != null) updates['location'] = location;
      if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;

      if (updates.isNotEmpty) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
        await _userRepository.updateUser(currentUserId, updates);

        // Update local user object
        final updatedUser = user.value.copyWith(
          displayName: displayName ?? user.value.displayName,
          username: username != null && username.trim().isNotEmpty
              ? username.trim().toLowerCase()
              : user.value.username,
          bio: bio ?? user.value.bio,
          website: website ?? user.value.website,
          location: location ?? user.value.location,
          avatarUrl: avatarUrl ?? user.value.avatarUrl,
        );
        user.value = updatedUser;

        if (avatarWillChange) {
          Get.snackbar('Success', 'Profile photo updated');
        } else {
          Get.snackbar('Success', 'Profile updated successfully!');
        }
        Get.back(); // Go back to profile view
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to update profile: ${e.toString()}');
    } finally {
      isEditLoading.value = false;
    }
  }

  Future<void> removeProfileImage() async {
    try {
      isEditLoading.value = true;
      final currentUserId = _authService.currentUser.value?.uid;
      if (currentUserId == null) return;

      await _userRepository.updateUser(currentUserId, {
        'avatarUrl': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      user.value = user.value.copyWith(avatarUrl: '');
      user.refresh();
      Get.snackbar('Success', 'Profile photo removed');
    } catch (e) {
      Get.snackbar('Error', 'Failed to remove profile photo: ${e.toString()}');
    } finally {
      isEditLoading.value = false;
    }
  }

  // Sub-step 5.10: Follow/Unfollow Logic
  Future<void> toggleFollow(String userId) async {
    if (isToggleFollowLoading.value) return;

    try {
      isToggleFollowLoading.value = true;
      final currentUserId = _authService.currentUser.value?.uid;
      if (currentUserId == null || currentUserId == userId) return;

      // Optimistic UI update
      final wasFollowing = isFollowing.value;
      isFollowing.value = !wasFollowing;

      // Update follower counts optimistically
      final currentUser = user.value;
      final newFollowersCount = wasFollowing
          ? currentUser.followersCount - 1
          : currentUser.followersCount + 1;

      user.value = currentUser.copyWith(followersCount: newFollowersCount);

      try {
        // Call SocialService to handle follow and notification
        final nowFollowing = await _socialService.toggleFollow(
          currentUserId: currentUserId,
          targetUserId: userId,
        );

        // Invalidate following cache to refresh feed immediately
        try {
          if (nowFollowing) {
            // User just followed - invalidate cache for this specific user
            _videoRepository.invalidateFollowingCache(currentUserId);
          } else {
            // User just unfollowed - clear entire cache to refresh feed
            _videoRepository.clearFollowingCache();
          }
        } catch (e) {
          // Log error but don't fail the follow operation
          Get.log('Failed to invalidate following cache: $e', isError: true);
        }

        Get.snackbar(
          'Success',
          nowFollowing
              ? 'Following ${currentUser.username}'
              : 'Unfollowed ${currentUser.username}',
        );
        // Refresh visible video count and list to reflect updated privacy
        // (e.g., hide followers-only videos immediately after unfollow).
        unawaited(_updateVisibleVideosCount());
        unawaited(loadUserVideos(userId, reset: true));
      } catch (e) {
        // Revert optimistic updates on error
        isFollowing.value = wasFollowing;
        user.value = currentUser;
        Get.snackbar(
          'Error',
          'Failed to ${wasFollowing ? 'unfollow' : 'follow'} user: ${e.toString()}',
        );
      }
    } finally {
      isToggleFollowLoading.value = false;
    }
  }

  /// Deletes a video with confirmation dialog
  Future<void> deleteVideo(String videoId) async {
    try {
      // Show confirmation dialog
      final confirmed = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Delete Video'),
          content: const Text(
            'Are you sure you want to delete this video? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Delete from repository
      await _videoRepository.deleteVideo(videoId);

      // Remove from local lists
      userVideos.removeWhere((video) => video.id == videoId);
      likedVideos.removeWhere((video) => video.id == videoId);
      savedVideos.removeWhere((video) => video.id == videoId);

      if (Get.isRegistered<VideoFeedCacheService>()) {
        try {
          Get.find<VideoFeedCacheService>().invalidateVideo(videoId);
        } catch (_) {
          // Ignore cache invalidation failures; feeds will refresh from network.
        }
      }

      // Notify feed controllers if registered to remove from feed
      final controllers = <VideoFeedController>[];
      if (Get.isRegistered<FollowersFeedController>()) {
        controllers.add(Get.find<FollowersFeedController>());
      }
      if (Get.isRegistered<VideoFeedController>()) {
        controllers.add(Get.find<VideoFeedController>());
      }

      for (final feedController in controllers) {
        try {
          feedController.removeVideoFromFeed(videoId);
        } catch (e) {
          // Feed controller not available, silently continue
          Get.log('[ProfileController] VideoFeedController not available: $e');
        }
      }

      Get.snackbar(
        'Success',
        'Video deleted successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete video: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  void onClose() {
    _userStreamSubscription?.cancel();
    _likedIdsSub?.cancel();
    _savedIdsSub?.cancel();
    for (final s in _likedVideoSubs.values) {
      s.cancel();
    }
    for (final s in _savedVideoSubs.values) {
      s.cancel();
    }
    _likedVideoSubs.clear();
    _savedVideoSubs.clear();
    super.onClose();
  }
}
