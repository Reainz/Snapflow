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

    // Support:
    // - snapflow://video/{videoId}  (host='video', path='/{videoId}')
    // - snapflow://user/{userId}    (host='user',  path='/{userId}')
    // - https://snapflow.app/video/{videoId} (pathSegments=['video','{id}'])
    // - https://snapflow.app/user/{userId}
    String? type;
    String? id;

    if (segments.length >= 2) {
      type = segments[0];
      id = segments[1];
    } else if (segments.length == 1 && uri.host.isNotEmpty) {
      // Custom scheme case where the "type" lives in the host.
      type = uri.host;
      id = segments[0];
    }

    if (type == null || id == null) return;

    final lower = type.toLowerCase();
    if (lower == 'video') {
      Get.toNamed(Routes.videoFeed, arguments: {
        'initialVideoId': id,
      });
      return;
    }
    if (lower == 'user') {
      Get.toNamed(Routes.profile, arguments: {
        'userId': id,
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
