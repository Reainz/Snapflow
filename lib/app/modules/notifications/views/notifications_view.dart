import 'package:flutter/material.dart';
import 'package:get/get.dart';
// timeago used within NotificationItemWidget

import '../controllers/notifications_controller.dart';
import '../../../routes/app_routes.dart';
import '../widgets/notification_item_widget.dart';

class NotificationsView extends GetView<NotificationsController> {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: controller.currentTab.value.clamp(0, 3),
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: const Text(
            'Notifications',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          bottom: TabBar(
            isScrollable: false,
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Likes'),
              Tab(text: 'Comments'),
              Tab(text: 'Follows'),
            ],
            onTap: (i) => controller.currentTab.value = i,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Notification settings',
              onPressed: () => Get.toNamed(Routes.notificationsSettings),
            ),
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: controller.markAllAsRead,
            ),
          ],
        ),
        body: Obx(() {
          final list = controller.filteredNotifications;
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_none_outlined,
                      size: 72,
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When you get notifications, they\'ll show up here',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 300),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              itemBuilder: (_, index) {
                final n = list[index];
                return _AnimatedNotificationCard(
                  child: NotificationItemWidget(
                notification: n,
                onTap: () async {
                  await controller.markAsRead(n.id);
                  final payload = n.payload ?? const {};
                  final route = payload['route'] as String? ?? '';
                  if (route == 'video' || route == 'comments') {
                    final vid = payload['videoId'] as String?;
                    if (vid != null && vid.isNotEmpty) {
                      Get.toNamed(Routes.comments, arguments: {'videoId': vid});
                      return;
                    }
                  }
                  if (route == 'profile') {
                    final uid = payload['userId'] as String?;
                    if (uid != null && uid.isNotEmpty) {
                      Get.toNamed(Routes.profile, arguments: {'userId': uid});
                      return;
                    }
                  }
                  Get.toNamed(Routes.notifications);
                },
              ),
            );
          },
        ),
      );
    }),
  ),
);
  }
}

// Animated notification card for tap scale feedback
class _AnimatedNotificationCard extends StatefulWidget {
  final Widget child;

  const _AnimatedNotificationCard({required this.child});

  @override
  State<_AnimatedNotificationCard> createState() => _AnimatedNotificationCardState();
}

class _AnimatedNotificationCardState extends State<_AnimatedNotificationCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}
