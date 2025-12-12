import 'package:get/get.dart';

import '../../profile/controllers/profile_controller.dart';
import '../../followers_feed/controllers/followers_feed_controller.dart';
import '../../video_feed/controllers/video_feed_controller.dart';
import '../../video_upload/controllers/video_upload_controller.dart';
import '../controllers/home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(HomeController.new);
    Get.lazyPut<VideoFeedController>(VideoFeedController.new, fenix: true);
    if (!Get.isRegistered<FollowersFeedController>()) {
      Get.lazyPut<FollowersFeedController>(FollowersFeedController.new, fenix: true);
    }
    Get.lazyPut<VideoUploadController>(VideoUploadController.new, fenix: true);
    Get.lazyPut<ProfileController>(ProfileController.new, fenix: true);
  }
}
