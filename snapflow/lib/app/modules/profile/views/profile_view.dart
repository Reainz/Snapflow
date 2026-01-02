import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/services/social_service.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_theme.dart';
import '../../../routes/app_routes.dart';
import '../controllers/profile_controller.dart';
import '../widgets/widgets.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    //
    //Determine if this ProfileView is shown as a standalone route (navigated
    // from Search/Followers) vs inside Home's Profile tab.
    final bool isStandaloneRoute = Get.currentRoute == Routes.profile;

    // If this view is embedded in the Home Profile tab, it must always reflect
    // the signed-in user's own profile. When returning from a standalone
    // profile route (opened from Followers/Following), the shared
    // ProfileController might still be pointing at the last viewed user.
    // Correct that here by switching back to the current user's id.
    if (!isStandaloneRoute) {
      final currentUid = Get.find<AuthService>().currentUser.value?.uid;
      if (currentUid != null && controller.targetUserId != currentUid) {
        // Always correct to the signed-in user when embedded in Home tab.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.openUser(currentUid);
          controller.markRouteArgApplied(currentUid);
        });
      }
    }

    // If this view was opened via a route with arguments, ensure the controller
    // switches to that user's profile even if an instance already existed.
    // This handles standalone profile views opened from Search or Followers.
    if (isStandaloneRoute) {
      final args = Get.arguments;
      if (args is Map && args['userId'] is String) {
        final argUserId = (args['userId'] as String).trim();
        if (argUserId.isNotEmpty && argUserId != controller.targetUserId) {
          // Defer until after first frame to avoid state changes during build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            controller.openUser(argUserId);
            controller.markRouteArgApplied(argUserId);
          });
        }
      }
    }

    void handleBack() {
      // For a consistent UX, always send the user back to their own profile
      // in the Home tab rather than the previous arbitrary screen.
      Get.offAllNamed(Routes.home, arguments: {'selectTab': 'profile'});
    }

    return Obx(() {
      if (controller.isLoading.value) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      // Privacy: Show Liked/Saved tabs only on own profile
      final tabCount = controller.isOwnProfile.value ? 3 : 1;

      final tabbedScaffold = DefaultTabController(
        length: tabCount,
        child: Scaffold(
          body: RefreshIndicator(
            onRefresh: controller.refreshProfile,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.pixels >=
                        notification.metrics.maxScrollExtent - 200 &&
                    controller.hasMoreVideos.value &&
                    !controller.isLoadingVideos.value) {
                  controller.loadUserVideos(controller.targetUserId);
                }
                return false;
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).primaryColor.withValues(alpha: 0.05),
                      Theme.of(context).primaryColor.withValues(alpha: 0.02),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.3, 1.0],
                  ),
                ),
                child: CustomScrollView(
                  slivers: [
                    // Always show AppBar to provide Share/Settings buttons
                    SliverAppBar(
                        floating: false,
                        // In the embedded Profile tab, let the top actions scroll away with the header
                        // (avoid fixed-position buttons hovering over content while scrolling).
                        pinned: isStandaloneRoute,
                        elevation: 0,
                        backgroundColor: isStandaloneRoute
                            ? Theme.of(context).scaffoldBackgroundColor
                            : Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        forceElevated: false,
                        leading: isStandaloneRoute
                            ? Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: handleBack,
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: PopupMenuButton<String>(
                                  icon: const Icon(Icons.settings),
                                  onSelected: (value) async {
                                    if (value == 'theme') {
                                      final themeService = Get.find<ThemeService>();
                                      await Get.dialog(
                                        AlertDialog(
                                          title: const Text('App Theme'),
                                          content: Obx(() {
                                            final mode = themeService.themeMode.value;
                                            return RadioGroup<ThemeMode>(
                                              groupValue: mode,
                                              onChanged: (value) {
                                                if (value == null) return;
                                                switch (value) {
                                                  case ThemeMode.light:
                                                    themeService.setLight();
                                                    break;
                                                  case ThemeMode.dark:
                                                    themeService.setDark();
                                                    break;
                                                  case ThemeMode.system:
                                                    themeService.setSystem();
                                                    break;
                                                }
                                                Get.back();
                                              },
                                              child: const Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  RadioListTile<ThemeMode>(
                                                    title: Text('Light'),
                                                    value: ThemeMode.light,
                                                  ),
                                                  RadioListTile<ThemeMode>(
                                                    title: Text('Dark'),
                                                    value: ThemeMode.dark,
                                                  ),
                                                  RadioListTile<ThemeMode>(
                                                    title: Text('System (Auto)'),
                                                    value: ThemeMode.system,
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Get.back(),
                                              child: const Text('Close'),
                                            ),
                                          ],
                                        ),
                                      );
                                    } else if (value == 'logout' || value == 'switch') {
                                      final confirmed = await Get.dialog<bool>(
                                        AlertDialog(
                                          title: const Text('Log out?'),
                                          content: const Text(
                                            'You will be signed out and can then log in with another account.',
                                          ),
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
                                          Get.offAllNamed(Routes.login);
                                        } catch (e) {
                                          Get.snackbar('Error', 'Failed to log out: $e');
                                        }
                                      }
                                    }
                                  },
                                  itemBuilder: (ctx) => const [
                                    PopupMenuItem(
                                      value: 'theme',
                                      child: ListTile(
                                        leading: Icon(Icons.brightness_6_outlined),
                                        title: Text('Theme'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'switch',
                                      child: ListTile(
                                        leading: Icon(Icons.switch_account_outlined),
                                        title: Text('Switch account'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'logout',
                                      child: ListTile(
                                        leading: Icon(Icons.logout),
                                        title: Text('Log out'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          actions: [
                            Padding(
                              padding: const EdgeInsets.only(right: 16.0),
                              child: IconButton(
                                icon: const Icon(Icons.share),
                                onPressed: () async {
                                  final social = Get.find<SocialService>();
                                  final user = controller.user.value;
                                  try {
                                    await social.shareProfile(user);
                                  } catch (e) {
                                    Get.snackbar(
                                      'Error',
                                      'Failed to share profile: $e',
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                      ),
                    SliverToBoxAdapter(
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          0, // Reduced top padding to move sections up
                          16,
                          12,
                        ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(height: 8),
                          ProfileHeaderWidget(),
                          SizedBox(height: 12),
                          ProfileStatsWidget(),
                          SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ProfileTabBarDelegate(
                      isOwnProfile: controller.isOwnProfile.value,
                    ),
                  ),
                  SliverFillRemaining(
                    child: TabBarView(
                      children: [
                        // Videos Tab - no padding for consistency
                        const UserVideosGrid(),
                        // Privacy: Only show Liked/Saved tabs on own profile
                        if (controller.isOwnProfile.value) ...[
                          // Liked Tab
                          const LikedVideosGrid(),
                          // Saved Tab
                          const SavedVideosGrid(),
                        ],
                      ],
                    ),
                  ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Intercept system back only when shown as a standalone route.
      if (isStandaloneRoute) {
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            handleBack();
          },
          child: tabbedScaffold,
        );
      }

      return tabbedScaffold;
    });
  }
}

const double _profileTabBarHeight = kTextTabBarHeight + 16;

class _ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  final bool isOwnProfile;

  const _ProfileTabBarDelegate({
    required this.isOwnProfile,
  });

  @override
  double get maxExtent => _profileTabBarHeight;

  @override
  double get minExtent => _profileTabBarHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isScrolled = shrinkOffset > 0;

    // Wrap in Obx to react to theme changes from ThemeService
    return Obx(() {
      // Access theme service to trigger rebuild on theme change
      final themeMode = Get.find<ThemeService>().themeMode.value;
      
      // Use Get.theme which properly reflects current theme mode
      // Theme.of(context) can be stale in SliverPersistentHeader delegates
      final isDark = themeMode == ThemeMode.dark ||
          (themeMode == ThemeMode.system &&
              MediaQuery.platformBrightnessOf(context) == Brightness.dark);
      
      final theme = isDark ? AppTheme.dark : AppTheme.light;
      final colorScheme = theme.colorScheme;
      
      // Use bright, high-contrast colors
      const selectedColor = Color(0xFF9575CD); // Bright purple for selected
      final unselectedColor = isDark 
          ? Colors.white.withValues(alpha: 0.7)  // Light gray on dark background
          : Colors.black.withValues(alpha: 0.6); // Dark gray on light background

      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          boxShadow: isScrolled ? [AppShadows.light] : [AppShadows.headerSubtle],
        ),
        child: Material(
          color: colorScheme.surface,
          child: TabBar(
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: UnderlineTabIndicator(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(width: 3, color: selectedColor),
            ),
            labelColor: selectedColor,
            unselectedLabelColor: unselectedColor,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            labelPadding: EdgeInsets.zero,
            tabs: const [
              Tab(icon: Icon(Icons.video_collection, size: 22), text: 'Videos'),
              Tab(icon: Icon(Icons.favorite, size: 22), text: 'Liked'),
              Tab(icon: Icon(Icons.bookmark, size: 22), text: 'Saved'),
            ].take(isOwnProfile ? 3 : 1).toList(),
          ),
        ),
      );
    });
  }

  @override
  bool shouldRebuild(covariant _ProfileTabBarDelegate oldDelegate) =>
      oldDelegate.isOwnProfile != isOwnProfile;
}
