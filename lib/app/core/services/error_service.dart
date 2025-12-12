import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LogConfig {
  // Set to true to enable verbose debug logging for real-time sync debugging.
  static bool verbose = true;
}

class ErrorService extends GetxService {
  void handleError(dynamic error, {String? context, StackTrace? stackTrace}) {
    // Always log errors to console for debugging (avoid print)
    Get.log(
      'ERROR${context != null ? ' [$context]' : ''}: $error',
      isError: true,
    );
    if (stackTrace != null) {
      Get.log('Stack trace: $stackTrace', isError: true);
    }
    
    if (LogConfig.verbose) {
      Get.log(
        'Error${context != null ? ' [$context]' : ''}: $error\n${stackTrace ?? ''}',
        isError: true,
      );
    }
    Get.snackbar(
      'Error',
      _userMessage(error),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade700,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  String _userMessage(dynamic error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('network')) {
      return 'Please check your internet connection.';
    }
    if (msg.contains('failed-precondition') || msg.contains('index') || msg.contains('requires an index')) {
      return 'Loading... Database is updating. Please wait a moment and try again.';
    }
    if (msg.contains('permission-denied') || msg.contains('insufficient permissions')) {
      return 'You don\'t have permission to access this content.';
    }
    return 'Something went wrong. Please try again.';
  }
}
