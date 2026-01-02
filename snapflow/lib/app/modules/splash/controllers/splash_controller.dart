import 'dart:async';

import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../routes/app_routes.dart';

class SplashController extends GetxController {
  final isLoading = true.obs;

  Timer? _navigationTimer;

  @override
  void onInit() {
    super.onInit();
    _navigationTimer = Timer(const Duration(seconds: 2), _checkAuthAndNavigate);
  }

  void _checkAuthAndNavigate() {
    if (!Get.isOverlaysOpen) {
      isLoading.value = false;

      // Check authentication status
      final authService = Get.find<AuthService>();
      final isAuthenticated = authService.currentUser.value != null;

      // Navigate based on authentication status
      if (isAuthenticated) {
        Get.offAllNamed(Routes.home);
      } else {
        Get.offAllNamed(Routes.login);
      }
    }
  }

  @override
  void onClose() {
    _navigationTimer?.cancel();
    super.onClose();
  }
}
