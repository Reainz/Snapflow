import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/filtered_video_feed_controller.dart';
import '../../video_feed/widgets/feed_video_page.dart';

/// A full-screen video feed that shows only liked or saved videos.
/// Allows vertical swiping through the filtered videos.
class FilteredVideoFeedView extends GetView<FilteredVideoFeedController> {
  const FilteredVideoFeedView({super.key});

  @override
  Widget build(BuildContext context) {
    // Set immersive full-screen mode
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        // Restore system UI when leaving
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
          overlays: SystemUiOverlay.values,
        );
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.scrim,
        extendBodyBehindAppBar: true,
        extendBody: true,
        body: Obx(() {
          if (controller.isLoading.value && controller.videos.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            );
          }

          if (controller.error.value.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      controller.error.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        SystemChrome.setEnabledSystemUIMode(
                          SystemUiMode.edgeToEdge,
                          overlays: SystemUiOverlay.values,
                        );
                        Get.back();
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (controller.videos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getEmptyIcon(),
                      size: 64,
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _getEmptyMessage(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        SystemChrome.setEnabledSystemUIMode(
                          SystemUiMode.edgeToEdge,
                          overlays: SystemUiOverlay.values,
                        );
                        Get.back();
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          // PageView for vertical scrolling through videos
          return Stack(
            children: [
              PageView.builder(
                controller: controller.pageController,
                scrollDirection: Axis.vertical,
                onPageChanged: controller.onPageChanged,
                itemCount: controller.videos.length,
                itemBuilder: (context, index) {
                  final video = controller.videos[index];
                  final isActive = controller.currentIndex.value == index;
                  return FeedVideoPage(
                    key: ValueKey('filtered_video_${video.id}_$index'),
                    video: video,
                    isActive: isActive,
                    onProfileTap: controller.openCreatorProfile,
                    onLikeTap: controller.handleLikeTap,
                    onCommentTap: controller.openComments,
                    onShareTap: controller.shareVideo,
                    onBookmarkTap: controller.toggleBookmark,
                  );
                },
              ),

              // Back button overlay
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        SystemChrome.setEnabledSystemUIMode(
                          SystemUiMode.edgeToEdge,
                          overlays: SystemUiOverlay.values,
                        );
                        Get.back();
                      },
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 24,
                            shadows: const [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 6,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Filter indicator (top-right) - only show for liked/saved feeds, not user videos
              if (controller.filterType.value == 'liked' || controller.filterType.value == 'saved')
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          controller.filterType.value == 'liked'
                              ? Icons.favorite
                              : Icons.bookmark,
                          size: 16,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          controller.filterType.value == 'liked'
                              ? 'Liked'
                              : 'Saved',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  IconData _getEmptyIcon() {
    switch (controller.filterType.value) {
      case 'liked':
        return Icons.favorite_border;
      case 'saved':
        return Icons.bookmark_border;
      case 'search':
        return Icons.search_off;
      case 'user':
        return Icons.video_library_outlined;
      default:
        return Icons.video_library_outlined;
    }
  }

  String _getEmptyMessage() {
    switch (controller.filterType.value) {
      case 'liked':
        return 'No liked videos yet';
      case 'saved':
        return 'No saved videos yet';
      case 'search':
        return 'No videos found';
      case 'user':
        return 'No videos uploaded yet';
      default:
        return 'No videos to display';
    }
  }
}
