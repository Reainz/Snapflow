import 'package:get/get.dart';

class MessagingController extends GetxController {
  final conversations = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    conversations.assignAll(['Team Snapflow', 'Creator Support']);
  }
}
