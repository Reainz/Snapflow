import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/services/update_service.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateDialog {
  static Future<void> show(UpdateService updateService) async {
    await Get.dialog(
      PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Update Required'),
          content: Text('Please update to version ${updateService.latestVersion.value} to continue using Snapflow.'),
          actions: [
            FilledButton(
              onPressed: () async {
                await openStoreUrl(updateService);
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }

  static Future<void> openStoreUrl(UpdateService updateService) async {
    final url = GetPlatform.isIOS ? updateService.iosUrl.value : updateService.androidUrl.value;
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar('Error', 'Could not open the store page.');
    }
  }
}
