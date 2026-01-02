import 'package:get/get.dart';

import '../controllers/video_upload_controller.dart';

class VideoUploadBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VideoUploadController>(VideoUploadController.new, fenix: true);
  }
}
