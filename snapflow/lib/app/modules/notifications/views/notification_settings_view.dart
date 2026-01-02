import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../data/repositories/notification_repository.dart';

class NotificationSettingsView extends StatefulWidget {
  const NotificationSettingsView({super.key});

  @override
  State<NotificationSettingsView> createState() => _NotificationSettingsViewState();
}

class _NotificationSettingsViewState extends State<NotificationSettingsView> {
  final _repo = Get.find<NotificationRepository>();
  final _auth = Get.find<AuthService>();

  bool _likes = true;
  bool _comments = true;
  bool _follows = true;
  bool _shares = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _auth.currentUser.value?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final prefs = await _repo.getUserNotificationPreferences(uid);
    setState(() {
      _likes = prefs.notifyLikes;
      _comments = prefs.notifyComments;
      _follows = prefs.notifyFollows;
      _shares = prefs.notifyShares;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final uid = _auth.currentUser.value?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await _repo.setUserNotificationPreferences(
        uid,
        NotificationPreferences(
          notifyLikes: _likes,
          notifyComments: _comments,
          notifyFollows: _follows,
          notifyShares: _shares,
        ),
      );
      if (mounted) {
        Get.snackbar('Saved', 'Notification preferences updated');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _saving
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: _save,
                    style: TextButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header section
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? const Color(0xFF2D2D3A) 
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark 
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.notifications_active,
                          color: colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Push Notifications',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Choose what you want to be notified about',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark 
                                    ? Colors.white.withValues(alpha: 0.6) 
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Settings cards
                _buildSettingCard(
                  context: context,
                  icon: Icons.favorite,
                  iconColor: Colors.redAccent,
                  title: 'Likes',
                  subtitle: 'When someone likes your video',
                  value: _likes,
                  onChanged: (v) => setState(() => _likes = v),
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildSettingCard(
                  context: context,
                  icon: Icons.comment,
                  iconColor: Colors.blueAccent,
                  title: 'Comments',
                  subtitle: 'When someone comments on your video',
                  value: _comments,
                  onChanged: (v) => setState(() => _comments = v),
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildSettingCard(
                  context: context,
                  icon: Icons.person_add,
                  iconColor: colorScheme.primary,
                  title: 'Follows',
                  subtitle: 'When someone starts following you',
                  value: _follows,
                  onChanged: (v) => setState(() => _follows = v),
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildSettingCard(
                  context: context,
                  icon: Icons.share,
                  iconColor: Colors.teal,
                  title: 'Shares',
                  subtitle: 'When someone shares your video',
                  value: _shares,
                  onChanged: (v) => setState(() => _shares = v),
                  isDark: isDark,
                ),
              ],
            ),
    );
  }

  Widget _buildSettingCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF2D2D3A) 
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark 
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark 
                        ? Colors.white.withValues(alpha: 0.6) 
                        : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: iconColor,
          ),
        ],
      ),
    );
  }
}
