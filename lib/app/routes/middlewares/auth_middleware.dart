import 'package:get/get.dart';
import 'package:flutter/widgets.dart';

import '../../core/services/auth_service.dart';
import '../../routes/app_routes.dart';

class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final auth = Get.find<AuthService>();
    final user = auth.currentUser.value;
    if (user == null) {
      return const RouteSettings(name: Routes.login);
    }
    return null;
  }
}
