import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../data/models/notification_model.dart';

class NotificationItemWidget extends StatelessWidget {
  const NotificationItemWidget({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final NotificationModel notification;
  final VoidCallback onTap;

  String? _videoStatus(NotificationModel notification) {
    final raw = notification.payload?['status'];
    if (raw is String) return raw.toLowerCase().trim();
    return null;
  }

  (IconData, Color) _visualForNotification(NotificationModel notification, ColorScheme colorScheme) {
    final type = notification.type;

    if (type == 'video') {
      final status = _videoStatus(notification);
      if (status == 'failed') {
        return (Icons.error_outline_rounded, Colors.redAccent);
      }
      if (status == 'ready') {
        return (Icons.cloud_done_rounded, Colors.green);
      }
      return (Icons.cloud_upload_rounded, Colors.blueGrey);
    }

    switch (type) {
      case 'like':
        return (Icons.favorite, Colors.redAccent);
      case 'comment':
        return (Icons.comment, Colors.blueAccent);
      case 'follow':
        return (Icons.person_add, colorScheme.primary);
      case 'share':
        return (Icons.share, Colors.teal);
      default:
        return (Icons.notifications_active, colorScheme.primary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (icon, accentColor) = _visualForNotification(notification, colorScheme);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF2D2D3A)  // Rich dark card
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark 
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon with accent color
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon, 
                    color: accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark 
                              ? Colors.white.withValues(alpha: 0.7) 
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• ${timeago.format(notification.createdAt, allowFromNow: true)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark 
                              ? Colors.white.withValues(alpha: 0.5) 
                              : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
                // Unread indicator
                if (!notification.read)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.4),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
