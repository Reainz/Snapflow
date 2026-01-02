import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../routes/app_routes.dart';
import '../../home/controllers/home_controller.dart';
import '../../../core/services/auth_service.dart';
import '../../notifications/controllers/notifications_controller.dart';
import '../../../core/services/update_service.dart';
import '../../../widgets/offline_banner.dart';
import '../../../widgets/update_dialog.dart';
import '../../followers_feed/controllers/followers_feed_controller.dart';
import '../../video_feed/controllers/video_feed_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _BottomNavItem(label: 'Feed', icon: Icons.play_arrow_rounded),
      _BottomNavItem(label: 'Upload', icon: Icons.cloud_upload_rounded),
      _BottomNavItem(label: 'Profile', icon: Icons.person_rounded),
    ];

    final updateService = Get.find<UpdateService>();
    final videoFeedController =
        Get.isRegistered<VideoFeedController>() ? Get.find<VideoFeedController>() : null;
    final followersFeedController = Get.isRegistered<FollowersFeedController>()
        ? Get.find<FollowersFeedController>()
        : null;

    // Kick an update check when home builds first time
    // (safe to call multiple times; cheap read)
    updateService.checkForUpdates(currentVersion: '1.0.0');
    // If force update, prompt a blocking dialog once
    ever(updateService.forceUpdate, (bool force) {
      if (force && updateService.needsUpdate.value) {
        _showForceUpdateDialog(updateService);
      }
    });

    return Obx(() {
      final isFeedTab = controller.selectedIndex.value == 0;
      final isFeedFullScreen = isFeedTab &&
          ((videoFeedController?.isFullScreenMode.value ?? false) ||
              (followersFeedController?.isFullScreenMode.value ?? false));
      final hideAppBar =
          controller.selectedIndex.value == 1 || controller.selectedIndex.value == 2 || isFeedFullScreen;
      final currentPage = controller.pages[controller.selectedIndex.value];

      Widget bodyContent;
      if (isFeedFullScreen) {
        bodyContent = currentPage;
      } else {
        bodyContent = Column(
          children: [
            const OfflineBanner(),
            Obx(() {
              if (!updateService.needsUpdate.value) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.secondary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      Icon(Icons.system_update, color: Theme.of(context).colorScheme.onSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          updateService.forceUpdate.value
                              ? 'A critical update (${updateService.latestVersion.value}) is required to continue.'
                              : 'Update available: ${updateService.latestVersion.value}',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSecondary),
                        ),
                      ),
                      TextButton(
                        onPressed: () => UpdateDialog.openStoreUrl(updateService),
                        child: Text('Update', style: TextStyle(color: Theme.of(context).colorScheme.onSecondary)),
                      ),
                    ],
                  ),
                ),
              );
            }),
            Expanded(child: currentPage),
          ],
        );
      }

      return Scaffold(
        appBar: hideAppBar
            ? null
            : AppBar(
                title: const Text('Snapflow'),
                actions: _buildAppBarActions(context),
              ),
        body: bodyContent,
        bottomNavigationBar: controller.selectedIndex.value == 1 || isFeedFullScreen
            ? null
            : NavigationBar(
                selectedIndex: controller.selectedIndex.value,
                destinations: tabs
                    .map(
                      (item) => NavigationDestination(
                        icon: Icon(item.icon),
                        label: item.label,
                      ),
                    )
                    .toList(),
                onDestinationSelected: controller.onTabSelected,
              ),
      );
    });
  }

  void _showForceUpdateDialog(UpdateService updateService) {
    UpdateDialog.show(updateService);
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    // When on Profile tab, show overflow menu with logout/switch account
    if (controller.selectedIndex.value == 2) {
      return [
        PopupMenuButton<_ProfileMenuAction>(
          icon: const Icon(Icons.more_vert),
          onSelected: (action) async {
            switch (action) {
              case _ProfileMenuAction.switchAccount:
              case _ProfileMenuAction.logout:
                await _confirmAndSignOut(context);
                break;
            }
          },
          itemBuilder: (ctx) {
            final items = <PopupMenuEntry<_ProfileMenuAction>>[];
            
            items.addAll(const [
              PopupMenuItem(
                value: _ProfileMenuAction.switchAccount,
                child: ListTile(
                  leading: Icon(Icons.switch_account_outlined),
                  title: Text('Switch account'),
                ),
              ),
              PopupMenuItem(
                value: _ProfileMenuAction.logout,
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Log out'),
                ),
              ),
            ]);
            
            return items;
          },
        ),
      ];
    }

    // Default actions for non-profile tabs
    return [
      IconButton(
        icon: const Icon(Icons.search),
        onPressed: () => Get.toNamed(Routes.search),
      ),
      Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Get.toNamed(Routes.notifications),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: Obx(() {
              if (!Get.isRegistered<NotificationsController>()) {
                return const SizedBox.shrink();
              }
              final nc = Get.find<NotificationsController>();
              final value = nc.unreadCount.value;
              if (value <= 0) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  value > 99 ? '99+' : '$value',
                  style: TextStyle(color: Theme.of(context).colorScheme.onError, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              );
            }),
          ),
        ],
      ),
    ];
  }

  Future<void> _confirmAndSignOut(BuildContext context) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
            'You will be signed out and can then log in with another account.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Get.back(result: true),
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Get.find<AuthService>().signOut();
        // Go to login to allow switching accounts
        Get.offAllNamed(Routes.login);
      } catch (e) {
        Get.snackbar('Error', 'Failed to log out: $e');
      }
    }
  }
}

class _BottomNavItem {
  const _BottomNavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

enum _ProfileMenuAction { switchAccount, logout }
