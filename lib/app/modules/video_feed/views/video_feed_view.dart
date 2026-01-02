import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../followers_feed/controllers/followers_feed_controller.dart';
import '../../followers_feed/views/followers_feed_view.dart';
import '../controllers/video_feed_controller.dart';
import 'feed_tab_page.dart';

class VideoFeedView extends GetView<VideoFeedController> {
  const VideoFeedView({super.key});

  @override
  Widget build(BuildContext context) {
    final followersController = Get.find<FollowersFeedController>();
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colorScheme.scrim,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // Video content (full screen)
              TabBarView(
                children: [
                  FeedTabPage(
                    controller: controller,
                    tabIndex: 0,
                    emptyBuilder: (context, ctrl) => FeedEmpty(
                      title: 'No public videos available yet',
                      message:
                          'Pull from the top or tap refresh to try again once creators start uploading content.',
                      primaryActionLabel: 'Refresh',
                      onPrimaryAction: ctrl.refreshFeed,
                    ),
                  ),
                  FollowersFeedView(
                    controller: followersController,
                    tabIndex: 1,
                  ),
                ],
              ),
              // Tab bar overlay (positioned at top)
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: _FeedTabs(colorScheme: colorScheme),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedTabs extends StatelessWidget {
  const _FeedTabs({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Container(
        width: 240,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TabBar(
          padding: EdgeInsets.zero,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
          indicator: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary,
                colorScheme.primary.withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          indicatorPadding: EdgeInsets.zero,
          labelStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            fontSize: 14,
            height: 1.0,
          ),
          unselectedLabelStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
            fontSize: 14,
            height: 1.0,
          ),
          tabs: const [
            Tab(
              height: 40,
              text: 'Public',
            ),
            Tab(
              height: 40,
              text: 'Following',
            ),
          ],
        ),
      ),
    );
  }
}
