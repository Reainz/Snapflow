import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/repositories/notification_repository.dart';

class NotificationsController extends GetxController {
  final NotificationRepository _repo = Get.find<NotificationRepository>();
  final AuthService _auth = Get.find<AuthService>();

  final notifications = <NotificationModel>[].obs;
  Stream<List<NotificationModel>>? _stream;
  StreamSubscription<List<NotificationModel>>? _sub;
  final currentTab = 0.obs; // 0: All, 1: Likes, 2: Comments, 3: Follows
  final unreadCount = 0.obs;

  List<NotificationModel> get filteredNotifications {
    final tab = currentTab.value;
    if (tab == 0) return notifications;
    final type = switch (tab) {
      1 => 'like',
      2 => 'comment',
      3 => 'follow',
      _ => null,
    };
    if (type == null) return notifications;
    return notifications.where((n) => n.type == type).toList(growable: false);
  }

  @override
  void onInit() {
    super.onInit();
    // Bind immediately if user already available
    _bindToUser(_auth.currentUser.value?.uid);
    // Re-bind when auth user changes
    ever(_auth.currentUser, (user) {
      _bindToUser((user as dynamic)?.uid as String?);
    });
  }

  void _bindToUser(String? uid) {
    if (uid == null || uid.isEmpty) {
      _sub?.cancel();
      _stream = null;
      notifications.clear();
      unreadCount.value = 0;
      return;
    }
    _sub?.cancel();
    _stream = _repo.notificationsStream(uid);
    _sub = _stream!.listen((items) {
      notifications.assignAll(items);
      unreadCount.value = items.where((n) => !n.read).length;
    });
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  Future<void> markAllAsRead() async {
    final uid = _auth.currentUser.value?.uid;
    if (uid == null) return;
    
    // Check if there are any unread notifications
    final unreadNotifications = notifications.where((n) => !n.read).toList();
    if (unreadNotifications.isEmpty) {
      Get.snackbar(
        'No Unread Notifications',
        'All notifications are already marked as read',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    
    try {
      await _repo.markAllAsRead(userId: uid);
      Get.snackbar(
        'Success',
        'All notifications marked as read',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to mark notifications as read',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final uid = _auth.currentUser.value?.uid;
    if (uid == null) return;
    await _repo.markAsRead(userId: uid, notificationId: notificationId);
    final idx = notifications.indexWhere((e) => e.id == notificationId);
    if (idx != -1) {
      notifications[idx] = notifications[idx].copyWith(read: true);
      notifications.refresh();
      unreadCount.value = notifications.where((n) => !n.read).length;
    }
  }
}
