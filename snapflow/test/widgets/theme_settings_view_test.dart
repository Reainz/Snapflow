import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:snapflow/app/core/services/auth_service.dart';
import 'package:snapflow/app/core/services/theme_service.dart';
import 'package:snapflow/app/data/repositories/notification_repository.dart';
import 'package:snapflow/app/modules/notifications/views/notification_settings_view.dart';

class FakeNotificationRepository extends NotificationRepository {
  NotificationPreferences prefs = const NotificationPreferences();

  @override
  Future<NotificationPreferences> getUserNotificationPreferences(String userId) async {
    return prefs;
  }

  @override
  Future<void> setUserNotificationPreferences(String userId, NotificationPreferences newPrefs) async {
    prefs = newPrefs;
  }
}

class FakeAuthService extends AuthService {
  final Rxn<User> _fakeCurrentUser = Rxn<User>();

  @override
  Rxn<User> get currentUser => _fakeCurrentUser;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    Get.reset();
    await GetStorage.init();
    await GetStorage().erase();

    final themeService = ThemeService();
    await themeService.init();
    Get.put<ThemeService>(themeService);
    Get.put<NotificationRepository>(FakeNotificationRepository());
    final auth = FakeAuthService();
    auth.currentUser.value = null; // ensure view sets _loading = false quickly
    Get.put<AuthService>(auth);
  });

  tearDown(() async {
    await GetStorage().erase();
    Get.reset();
  });

  testWidgets('theme radios update ThemeService', (tester) async {
    final themeService = Get.find<ThemeService>();

    await tester.pumpWidget(const GetMaterialApp(home: NotificationSettingsView()));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(themeService.themeMode.value, ThemeMode.dark);

    await tester.tap(find.text('System (Auto)'));
    await tester.pumpAndSettle();
    expect(themeService.themeMode.value, ThemeMode.system);
  }, skip: true);
}
