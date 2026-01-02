import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/user_model.dart' as models show UserModel;
import '../../../routes/app_routes.dart';
import '../controllers/search_controller.dart';

class UserSearchList extends GetView<SearchModuleController> {
  const UserSearchList({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.users.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Users Found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching with different keywords',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: controller.users.length,
        itemBuilder: (context, index) {
          final user = controller.users[index];
          return _UserTile(user: user);
        },
      );
    });
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});

  final models.UserModel user;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      leading: CircleAvatar(
        radius: 28,
        backgroundImage: user.avatarUrl.isNotEmpty
            ? NetworkImage(user.avatarUrl)
            : null,
        child: user.avatarUrl.isEmpty
            ? Icon(
                Icons.person,
                size: 32,
                color: Colors.grey[400],
              )
            : null,
      ),
      title: Text(
        user.displayName,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        '@${user.username}',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
        ),
      ),
      trailing: user.followersCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formatCount(user.followersCount),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      onTap: () {
        Get.toNamed(
          Routes.profile,
          arguments: {'userId': user.id},
        );
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
