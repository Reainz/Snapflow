import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/video_model.dart';
import '../controllers/video_feed_controller.dart';
import '../../followers_feed/controllers/followers_feed_controller.dart';
import 'video_action_bar.dart';
import 'video_info_overlay.dart';
import 'video_player_widget.dart';

class FeedVideoPage extends StatefulWidget {
  const FeedVideoPage({
    super.key,
    required this.video,
    required this.isActive,
    this.onRefreshRequested,
    this.onProfileTap,
    this.onHashtagTap,
    this.onLikeTap,
    this.onCommentTap,
    this.onShareTap,
    this.onBookmarkTap,
    this.onFlagTap,
  });

  final VideoModel video;
  final bool isActive;
  final Future<void> Function()? onRefreshRequested;

  final void Function(VideoModel video)? onProfileTap;
  final void Function(String hashtag)? onHashtagTap;
  final void Function(VideoModel video)? onLikeTap;
  final void Function(VideoModel video)? onCommentTap;
  final void Function(VideoModel video)? onShareTap;
  final void Function(VideoModel video)? onBookmarkTap;
  final void Function(VideoModel video)? onFlagTap;

  @override
  State<FeedVideoPage> createState() => _FeedVideoPageState();
}

class _FeedVideoPageState extends State<FeedVideoPage> {
  bool _showLikeBurst = false;
  Timer? _likeBurstTimer;
  final GlobalKey _videoPlayerKey = GlobalKey();

  @override
  void dispose() {
    _likeBurstTimer?.cancel();
    super.dispose();
  }

  bool get _hasPlayableVideo => widget.video.hlsUrl.isNotEmpty;

  @override
  Widget build(BuildContext context) {
     // Try to find VideoFeedController, but don't fail if it doesn't exist
    // (e.g., when used in FilteredVideoFeedView)
    VideoFeedController? controller;
    try {
      if (Get.isRegistered<FollowersFeedController>()) {
        controller = Get.find<FollowersFeedController>();
      } else if (Get.isRegistered<VideoFeedController>()) {
        controller = Get.find<VideoFeedController>();
      }
    } catch (e) {
      // Controller not found, will use callbacks instead
      controller = null;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        VideoPlayerWidget(
          key: _videoPlayerKey,
          video: widget.video,
          isActive: widget.isActive,
          onDoubleTap: () {
            _handleLikeTap(controller);
          },
        ),
        Obx(() {
          final isFullScreen = controller?.isFullScreenMode.value ?? false;
          if (isFullScreen) return const SizedBox.shrink();
          return const _GradientOverlay();
        }),
        Obx(() {
          final isFullScreen = controller?.isFullScreenMode.value ?? false;
          if (isFullScreen) return const SizedBox.shrink();
          // Get playing state from VideoPlayerWidget
          final videoPlayerState = _videoPlayerKey.currentState;
          final isPlaying = (videoPlayerState as dynamic).isPlaying as RxBool?;
          return VideoInfoOverlay(
            video: widget.video,
            isPlaying: isPlaying,
            onProfileTap: () => _handleProfileTap(controller),
            onHashtagTap: (tag) => _handleHashtagTap(controller, tag),
          );
        }),
        Obx(() {
          final isFullScreen = controller?.isFullScreenMode.value ?? false;
          if (isFullScreen) return const SizedBox.shrink();
          return VideoActionBar(
            video: widget.video,
            onProfileTap: () => _handleProfileTap(controller),
            onLikeTap: () => _handleLikeTap(controller),
            onCommentTap: () => _handleCommentTap(controller),
            onShareTap: () => _handleShareTap(controller),
            onBookmarkTap: () => _handleBookmarkTap(controller),
            onFlagTap: () => _handleFlagTap(controller),
          );
        }),
        if (!_hasPlayableVideo)
          _VideoErrorOverlay(onRefreshRequested: widget.onRefreshRequested),
        AnimatedOpacity(
          opacity: _showLikeBurst ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: const _HeartBurstOverlay(),
        ),
      ],
    );
  }

  void _triggerLikeBurst() {
    _likeBurstTimer?.cancel();
    setState(() => _showLikeBurst = true);
    _likeBurstTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _showLikeBurst = false);
      }
    });
  }

  void _handleProfileTap(VideoFeedController? controller) {
    if (widget.onProfileTap != null) {
      widget.onProfileTap!(widget.video);
    } else if (controller != null) {
      controller.openCreatorProfile(widget.video);
    }
  }

  void _handleHashtagTap(VideoFeedController? controller, String hashtag) {
    if (widget.onHashtagTap != null) {
      widget.onHashtagTap!(hashtag);
    } else if (controller != null) {
      controller.onHashtagTapped(hashtag);
    }
  }

  void _handleLikeTap(VideoFeedController? controller) {
    final wasLiked = widget.video.isLiked;
    if (widget.onLikeTap != null) {
      widget.onLikeTap!(widget.video);
    } else if (controller != null) {
      controller.handleLikeTap(widget.video);
    }
    if (!wasLiked) {
      _triggerLikeBurst();
    }
  }

  void _handleCommentTap(VideoFeedController? controller) {
    if (widget.onCommentTap != null) {
      widget.onCommentTap!(widget.video);
    } else if (controller != null) {
      controller.openComments(widget.video);
    }
  }

  void _handleShareTap(VideoFeedController? controller) {
    if (widget.onShareTap != null) {
      widget.onShareTap!(widget.video);
    } else if (controller != null) {
      controller.shareVideo(widget.video);
    }
  }

  void _handleBookmarkTap(VideoFeedController? controller) {
    if (widget.onBookmarkTap != null) {
      widget.onBookmarkTap!(widget.video);
    } else if (controller != null) {
      controller.toggleBookmark(widget.video);
    }
  }

  void _handleFlagTap(VideoFeedController? controller) {
    if (widget.onFlagTap != null) {
      widget.onFlagTap!(widget.video);
    } else if (controller != null) {
      controller.flagVideo(widget.video);
    }
  }
}

class _GradientOverlay extends StatelessWidget {
  const _GradientOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black54,
              Colors.transparent,
              Colors.transparent,
              Colors.black87,
            ],
            stops: [0, 0.2, 0.7, 1],
          ),
        ),
      ),
    );
  }
}

class _HeartBurstOverlay extends StatelessWidget {
  const _HeartBurstOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.4),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Icon(
            Icons.favorite_rounded,
            color: Colors.white,
            size: 120,
            shadows: [
              Shadow(
                color: Colors.red.withValues(alpha: 0.8),
                blurRadius: 20,
              ),
              const Shadow(
                color: Colors.black38,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoErrorOverlay extends StatelessWidget {
  const _VideoErrorOverlay({this.onRefreshRequested});

  final Future<void> Function()? onRefreshRequested;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7), size: 48),
          const SizedBox(height: 12),
          Text(
            'We couldn\'t play this video.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again in a moment.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)),
          ),
          if (onRefreshRequested != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => onRefreshRequested?.call(),
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}
