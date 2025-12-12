import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

/// Provides a reactive online/offline status by combining network
/// connectivity events with an Internet reachability check.
class ConnectivityService extends GetxService {
  final isOnline = true.obs;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool get _isTestEnv => Platform.environment['FLUTTER_TEST'] == 'true';

  @override
  void onInit() {
    super.onInit();
    // In Flutter tests, avoid creating timers/subscriptions that outlive the test frame.
    if (_isTestEnv) {
      isOnline.value = true; // assume online in tests
      return;
    }
    // Initial check
    _checkReachability();
    _sub = Connectivity().onConnectivityChanged.listen((_) async {
      await _checkReachability();
    });
  }

  Future<void> _checkReachability() async {
    try {
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 3));
      isOnline.value = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      isOnline.value = false;
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
