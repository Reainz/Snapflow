import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';

class AuthView extends GetView<AuthController> {
  const AuthView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in to Snapflow')),
      body: Center(
        child: Obx(
          () => FilledButton.icon(
            onPressed: controller.isLoading.value ? null : controller.login,
            icon: controller.isLoading.value
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: Text(
              controller.isLoading.value
                  ? 'Signing In...'
                  : 'Continue with Email',
            ),
          ),
        ),
      ),
    );
  }
}
