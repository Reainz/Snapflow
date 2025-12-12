import 'package:get/get.dart';

import '../controllers/messaging_controller.dart';

class MessagingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MessagingController>(MessagingController.new);
  }
}
