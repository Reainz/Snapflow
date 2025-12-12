import 'package:get/get.dart';
import 'package:snapflow/app/modules/profile/controllers/follow_list_controller.dart';

class FollowListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FollowListController>(() => FollowListController());
  }
}
