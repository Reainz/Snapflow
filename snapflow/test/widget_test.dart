// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:snapflow/app/core/services/video_feed_cache_service.dart';
import 'package:snapflow/app/routes/app_routes.dart';
import 'package:snapflow/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Mock path_provider for GetStorage
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.path;
        }
        return null;
      },
    );

    // Initialize GetStorage
    await GetStorage.init('video_feed_cache');
  });

  setUp(() async {
    Get.reset();
    Get.testMode = true;

    // Register cache services for testing
    // Note: GetX will automatically call onInit() when services are registered
    Get.put<VideoFeedCacheService>(VideoFeedCacheService(maxSize: 50));
  });

  tearDown(Get.reset);

  testWidgets('Snapflow app renders splash screen', (tester) async {
    await tester.pumpWidget(const SnapflowApp());
    // Allow any pending timers/microtasks from service initialization to complete
    await tester.pumpAndSettle();

    expect(find.text('Snapflow'), findsWidgets);
    expect(Get.currentRoute, Routes.splash);
  });
}
