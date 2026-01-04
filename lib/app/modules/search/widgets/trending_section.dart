import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';

import '../controllers/search_controller.dart';

class TrendingSection extends GetView<SearchModuleController> {
  const TrendingSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingTrending.value) {
        return const Center(child: CircularProgressIndicator());
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (controller.trendingHashtags.isNotEmpty) ...[
              _SectionHeader(
                icon: Icons.trending_up,
                title: 'Trending Hashtags',
                subtitle: 'Popular topics right now',
              ),
              const SizedBox(height: 16),
              _HashtagsList(
                hashtags: controller.trendingHashtags,
                onHashtagTap: controller.searchByHashtag,
              ),
              const SizedBox(height: 24),
            ],
            if (controller.trendingUsers.isNotEmpty) ...[
              _SectionHeader(
                icon: Icons.star,
                title: 'Trending Creators',
                subtitle: 'Creators gaining traction this week',
              ),
              const SizedBox(height: 12),
              _TrendingUsersList(),
            ],
          ],
        ),
      );
    });
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrendingUsersList extends GetView<SearchModuleController> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: controller.trendingUsers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final user = controller.trendingUsers[index];
          return GestureDetector(
            onTap: () {
              Get.toNamed(
                Routes.profile,
                arguments: {'userId': user.id},
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage:
                      user.avatarUrl.isNotEmpty ? NetworkImage(user.avatarUrl) : null,
                  child: user.avatarUrl.isEmpty
                      ? Text(
                          (user.displayName.isNotEmpty
                                  ? user.displayName
                                  : user.username)
                              .substring(0, 1)
                              .toUpperCase(),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 80,
                  child: Text(
                    user.displayName.isNotEmpty ? user.displayName : user.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HashtagsList extends StatelessWidget {
  const _HashtagsList({
    required this.hashtags,
    required this.onHashtagTap,
  });

  final List<String> hashtags;
  final void Function(String) onHashtagTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: hashtags.map((hashtag) {
        return GestureDetector(
          onTap: () => onHashtagTap(hashtag),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.tag,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  hashtag.replaceAll('#', ''),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
