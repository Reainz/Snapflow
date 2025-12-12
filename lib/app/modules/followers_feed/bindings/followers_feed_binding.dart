import 'package:get/get.dart';

import '../controllers/followers_feed_controller.dart';

class FollowersFeedBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FollowersFeedController>(FollowersFeedController.new);
  }
}
