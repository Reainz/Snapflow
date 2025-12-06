import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/video_feed_controller.dart';
import '../widgets/feed_video_page.dart';
import '../widgets/video_loading_placeholder.dart';
import '../../../routes/app_routes.dart';

typedef FeedEmptyBuilder = Widget Function(BuildContext context, VideoFeedController controller);

class FeedTabPage extends StatelessWidget {
  const FeedTabPage({
    super.key,
    required this.controller,
    required this.emptyBuilder,
    required this.tabIndex,
  });

  final VideoFeedController controller;
  final FeedEmptyBuilder emptyBuilder;
  final int tabIndex;

  @override
  Widget build(BuildContext context) {
    final tabController = DefaultTabController.of(context);

    Widget buildContent() {
      return Container(
        color: Theme.of(context).colorScheme.scrim,
        child: Obx(() {
          if (controller.isLoading.value && controller.videos.isEmpty) {
            return const VideoLoadingPlaceholder();
          }

          if (controller.videos.isEmpty) {
            return emptyBuilder(context, controller);
          }

          final animationValue = tabController?.animation?.value;
          final isTabActive = tabController == null
              ? true
              : tabController.index == tabIndex ||
                  (animationValue != null && animationValue.round() == tabIndex);
          final overlayTop = MediaQuery.of(context).padding.top + 40;
          final showStandaloneBackButton = Get.currentRoute == Routes.videoFeed;
          final actionLeftOffset = showStandaloneBackButton ? 72.0 : 16.0;

          return Stack(
            children: [
              PageView.builder(
                controller: controller.pageController,
                scrollDirection: Axis.vertical,
                allowImplicitScrolling: true,
                onPageChanged: controller.onPageChanged,
                itemCount: controller.videos.length,
                itemBuilder: (context, index) {
                  final video = controller.videos[index];
                  return Obx(() {
                    final isActive = controller.currentIndex.value == index && isTabActive;
                    return FeedVideoPage(
                      key: ValueKey('feed_video_${video.id}_$index'),
                      video: video,
                      isActive: isActive,
                      onRefreshRequested: controller.refreshFeed,
                      onProfileTap: controller.openCreatorProfile,
                      onHashtagTap: controller.onHashtagTapped,
                      onLikeTap: controller.handleLikeTap,
                      onCommentTap: controller.openComments,
                      onShareTap: controller.shareVideo,
                      onBookmarkTap: controller.toggleBookmark,
                      onFlagTap: controller.flagVideo,
                    );
                  });
                },
              ),
              Positioned(
                top: overlayTop,
                left: actionLeftOffset,
                child: Obx(() {
                  final isFullScreen = controller.isFullScreenMode.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FullScreenButton(
                        isFullScreen: isFullScreen,
                        onPressed: controller.toggleFullScreenMode,
                      ),
                      if (!isFullScreen) ...[
                        const SizedBox(height: 12),
                        _RefreshButton(
                          isRefreshing: controller.isRefreshing.value,
                          onPressed: controller.isRefreshing.value
                              ? null
                              : controller.refreshFeed,
                        ),
                      ],
                    ],
                  );
                }),
              ),
              if (controller.isLoadingMore.value)
                const Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: _BottomLoader(),
                ),
              // Back button when opened as a standalone route (e.g., from Profile grids)
              if (showStandaloneBackButton)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 12,
                  child: _BackButtonOverlay(),
                ),
              
              // Offline indicator - shows when no connectivity
              if (!controller.isOnline.value)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 48,
                  left: 16,
                  right: 16,
                  child: const _OfflineIndicator(),
                ),
              
              // Cache loading indicator - shows during initial load with connectivity
              if (controller.isLoading.value && 
                  controller.videos.isEmpty && 
                  controller.isOnline.value)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 48,
                  left: 16,
                  right: 16,
                  child: const _CacheLoadingIndicator(),
                ),
              
              // Refresh indicator - shows during pull-to-refresh
              if (controller.isRefreshing.value)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 48,
                  left: 16,
                  right: 16,
                  child: const _RefreshingIndicator(),
                ),
            ],
          );
        }),
      );
    }

    if (tabController == null) {
      return buildContent();
    }

    return AnimatedBuilder(
      animation: tabController.animation ?? tabController,
      builder: (context, _) => buildContent(),
    );
  }
}

class _BackButtonOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Get.back();
            }
          },
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 24,
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomLoader extends StatelessWidget {
  const _BottomLoader();

  @override
  Widget build(BuildContext context) {
    // Use compact shimmer placeholder for pagination loading
    return const Center(
      child: CompactVideoLoadingPlaceholder(),
    );
  }
}

class FeedEmpty extends StatelessWidget {
  const FeedEmpty({
    required this.title,
    required this.message,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String title;
  final String message;
  final String primaryActionLabel;
  final Future<void> Function()? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withOpacity(0.2),
                  colorScheme.primary.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.2),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              Icons.play_circle_outline_rounded,
              size: 64,
              color: colorScheme.primary,
              shadows: [
                Shadow(
                  color: colorScheme.primary.withOpacity(0.5),
                  blurRadius: 16,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.7),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onPrimaryAction,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 36,
                        vertical: 16,
                      ),
                      child: Text(
                        primaryActionLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (secondaryActionLabel != null && onSecondaryAction != null) ...[
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onSecondaryAction,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        child: Text(
                          secondaryActionLabel!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FullScreenButton extends StatelessWidget {
  const _FullScreenButton({required this.isFullScreen, required this.onPressed});

  final bool isFullScreen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Icon(
                isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                color: Colors.white,
                size: 24,
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.isRefreshing, this.onPressed});

  final bool isRefreshing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: isRefreshing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 24,
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineIndicator extends StatelessWidget {
  const _OfflineIndicator();

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.95),
            Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.wifi_off,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Offline Mode',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Using cached videos',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.cloud_done_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CacheLoadingIndicator extends StatelessWidget {
  const _CacheLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Loading cached videos...',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshingIndicator extends StatelessWidget {
  const _RefreshingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Refreshing feed...',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
