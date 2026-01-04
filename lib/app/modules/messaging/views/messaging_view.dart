import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/messaging_controller.dart';

class MessagingView extends GetView<MessagingController> {
  const MessagingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: Obx(
        () => ListView.builder(
          itemCount: controller.conversations.length,
          itemBuilder: (_, index) => ListTile(
            leading: const CircleAvatar(child: Icon(Icons.chat_bubble_outline)),
            title: Text(controller.conversations[index]),
            subtitle: const Text('Say hello to your community'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
        ),
      ),
    );
  }
}
