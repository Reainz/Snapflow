import 'package:get/get.dart';

import '../../followers_feed/controllers/followers_feed_controller.dart';
import '../controllers/video_feed_controller.dart';

class VideoFeedBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VideoFeedController>(VideoFeedController.new);
    if (!Get.isRegistered<FollowersFeedController>()) {
      Get.lazyPut<FollowersFeedController>(FollowersFeedController.new);
    }
  }
}
