import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class UpdateInfo {
  UpdateInfo({
    required this.latestVersion,
    required this.force,
    required this.androidUrl,
    required this.iosUrl,
  });

  final String latestVersion;
  final bool force;
  final String androidUrl;
  final String iosUrl;
}

/// Fetches app update metadata from Firestore collection `app_config/app`
/// Document fields:
/// - latestVersion: string (e.g., 1.0.2)
/// - forceUpdate: bool
/// - androidUrl: string (Play Store listing)
/// - iosUrl: string (App Store listing)
class UpdateService extends GetxService {
  final needsUpdate = false.obs;
  final forceUpdate = false.obs;
  final latestVersion = ''.obs;
  final androidUrl = ''.obs;
  final iosUrl = ''.obs;

  Future<void> checkForUpdates({required String currentVersion}) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('app')
          .get();
      final data = doc.data();
      if (data == null) return;

      final latest = (data['latestVersion'] ?? '').toString();
      final force = (data['forceUpdate'] ?? false) == true;
      final aUrl = (data['androidUrl'] ?? '').toString();
      final iUrl = (data['iosUrl'] ?? '').toString();

      latestVersion.value = latest;
      forceUpdate.value = force;
      androidUrl.value = aUrl;
      iosUrl.value = iUrl;

      needsUpdate.value = _isNewer(latest, currentVersion);
    } catch (e) {
      if (kDebugMode) Get.log('UpdateService check failed: $e', isError: true);
    }
  }

  bool _isNewer(String latest, String current) {
    List<int> parse(String v) => v
        .split('.')
        .map((e) => int.tryParse(e.trim()) ?? 0)
        .toList(growable: false);
    final l = parse(latest);
    final c = parse(current);
    for (var i = 0; i < 3; i++) {
      final li = i < l.length ? l[i] : 0;
      final ci = i < c.length ? c[i] : 0;
      if (li > ci) return true;
      if (li < ci) return false;
    }
    return false;
  }
}
