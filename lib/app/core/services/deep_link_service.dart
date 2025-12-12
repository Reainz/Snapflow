import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:app_links/app_links.dart';

import '../../routes/app_routes.dart';

/// Handles deep links for profile and video sharing.
/// Supported links:
/// - snapflow://video/{videoId}
/// - snapflow://user/{userId}
/// - https://snapflow.app/video/{videoId}
/// - https://snapflow.app/user/{userId}
class DeepLinkService extends GetxService {
  StreamSubscription? _sub;
  late final AppLinks _appLinks;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    _appLinks = AppLinks();
    // Subscribe to all events (initial link and further) - app_links emits the
    // initial link on the stream as well when registered early enough.
    _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen((uri) {
      _handleUri(uri);
    }, onError: (e) {
      if (kDebugMode) Get.log('DeepLink stream error: $e', isError: true);
    });
  }

  void _handleUri(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return;

    // Support custom scheme or https
    final first = segments.first;
    if (first.toLowerCase() == 'video' && segments.length >= 2) {
      final videoId = segments[1];
      Get.toNamed(Routes.videoFeed, arguments: {
        'initialVideoId': videoId,
      });
      return;
    }
    if (first.toLowerCase() == 'user' && segments.length >= 2) {
      final userId = segments[1];
      Get.toNamed(Routes.profile, arguments: {
        'userId': userId,
      });
      return;
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
