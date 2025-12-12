import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../video_feed/views/video_feed_view.dart';
import '../../video_upload/views/video_upload_view.dart';
import '../../profile/views/profile_view.dart';
import '../../profile/controllers/profile_controller.dart';
import '../../../core/services/auth_service.dart';

class HomeController extends GetxController {
  final selectedIndex = 0.obs;
  bool _initialArgsApplied = false;

  final pages = const <Widget>[
    VideoFeedView(),
    VideoUploadView(),
    ProfileView(),
  ];

  @override
  void onInit() {
    super.onInit();
    // If navigated with a request to select a specific tab, apply it.
    final args = Get.arguments;
    if (args is Map && args['selectTab'] is String) {
      final tab = (args['selectTab'] as String).toLowerCase();
      if (tab == 'profile') {
        selectedIndex.value = 2;
      } else if (tab == 'upload') {
        selectedIndex.value = 1;
      } else {
        selectedIndex.value = 0;
      }
      _initialArgsApplied = true;
    }
  }

  @override
  void onReady() {
    super.onReady();
    // Apply route arguments again post-build to avoid any timing issues.
    if (_initialArgsApplied) return;
    final args = Get.arguments;
    if (args is Map && args['selectTab'] is String) {
      final tab = (args['selectTab'] as String).toLowerCase();
      if (tab == 'profile') {
        onTabSelected(2);
      } else if (tab == 'upload') {
        onTabSelected(1);
      } else {
        onTabSelected(0);
      }
      _initialArgsApplied = true;
    }
  }

  void onTabSelected(int index) {
    selectedIndex.value = index;
    Get.log('HomeController: onTabSelected -> $index');
    // Ensure ProfileController exists when switching to Profile tab
    if (index == 2 && !Get.isRegistered<ProfileController>()) {
      Get.log(
        'HomeController: ProfileController not registered, registering now...',
      );
      Get.lazyPut<ProfileController>(ProfileController.new, fenix: true);
    }

    // When user selects Profile tab, always show the current user's profile.
    if (index == 2) {
      final auth = Get.find<AuthService>();
      final uid = auth.currentUser.value?.uid;
      Get.log('HomeController: Profile tab selected, currentUser uid=$uid');
      if (uid != null) {
        // Directly call openUser to ensure the profile is always loaded.
        Get.log('HomeController: Calling ProfileController.openUser($uid)');
        Get.find<ProfileController>().openUser(uid);
      } else {
        Get.log(
          'HomeController: uid is null, cannot load profile',
          isError: true,
        );
      }
    }
  }
}
