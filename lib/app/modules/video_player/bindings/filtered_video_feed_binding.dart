import 'package:get/get.dart';

import '../controllers/filtered_video_feed_controller.dart';

class FilteredVideoFeedBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FilteredVideoFeedController>(
      () => FilteredVideoFeedController(),
    );
  }
}

