import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../video_feed/views/feed_tab_page.dart';
import '../../../routes/app_routes.dart';
import '../controllers/followers_feed_controller.dart';

class FollowersFeedView extends GetView<FollowersFeedController> {
  const FollowersFeedView({
    super.key,
    required this.tabIndex,
    FollowersFeedController? controller,
  }) : _providedController = controller;

  final FollowersFeedController? _providedController;
  final int tabIndex;

  @override
  FollowersFeedController get controller =>
      _providedController ?? Get.find<FollowersFeedController>();

  @override
  Widget build(BuildContext context) {
    return FeedTabPage(
      controller: controller,
      tabIndex: tabIndex,
      emptyBuilder: (context, ctrl) {
        return Obx(() {
          if (!ctrl.isAuthenticated.value) {
            return FeedEmpty(
              title: 'Sign in to follow creators',
              message: 'Followers-only videos show up once you follow creators you love.',
              primaryActionLabel: 'Sign in',
              onPrimaryAction: () async {
                await Get.toNamed(Routes.login);
              },
              secondaryActionLabel: 'Public feed',
              onSecondaryAction: () => DefaultTabController.of(context).animateTo(0),
            );
          }

          if (!ctrl.hasFollowedCreators.value) {
            return FeedEmpty(
              title: 'Follow creators to see exclusives',
              message: 'Start following creators to unlock their followers-only drops.',
              primaryActionLabel: 'Find creators',
              onPrimaryAction: () async {
                await Get.toNamed(Routes.search);
              },
              secondaryActionLabel: 'Refresh',
              onSecondaryAction: () {
                ctrl.refreshFeed();
              },
            );
          }

          return FeedEmpty(
            title: 'No followers-only videos yet',
            message: 'The creators you follow have not shared followers-only videos yet.',
            primaryActionLabel: 'Refresh',
            onPrimaryAction: ctrl.refreshFeed,
          );
        });
      },
    );
  }
}
