import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/video_model.dart';
import '../../followers_feed/controllers/followers_feed_controller.dart';
import '../controllers/video_feed_controller.dart';

class VideoInfoOverlay extends StatefulWidget {
  const VideoInfoOverlay({
    super.key,
    required this.video,
    this.onProfileTap,
    this.onHashtagTap,
    this.isPlaying,
  });

  final VideoModel video;
  final VoidCallback? onProfileTap;
  final void Function(String hashtag)? onHashtagTap;
  final RxBool? isPlaying;

  @override
  State<VideoInfoOverlay> createState() => _VideoInfoOverlayState();
}

class _VideoInfoOverlayState extends State<VideoInfoOverlay> {
  late Future<UserModel?> _creatorFuture;

  @override
  void initState() {
    super.initState();
    _creatorFuture = _loadCreator();
  }

  @override
  void didUpdateWidget(covariant VideoInfoOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.ownerId != widget.video.ownerId) {
      _creatorFuture = _loadCreator();
    }
  }

  Future<UserModel?> _loadCreator() async {
    try {
      final controller = _resolveController();
      return controller.fetchCreator(widget.video.ownerId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use hashtags from video model if available, otherwise extract from description
    final hashtags = widget.video.hashtags.isNotEmpty 
        ? widget.video.hashtags.take(5).toList()
        : _extractHashtags(widget.video.description);
    return Obx(() {
      // When playing (no progress bar): bottom = 50 (lower position)
      // When paused (progress bar visible): bottom = 110 (higher position)
      final isPlayingValue = widget.isPlaying?.value ?? true;
      final bottomPosition = isPlayingValue ? 50.0 : 110.0;
      
      return AnimatedPositioned(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        left: 16,
        right: 96,
        bottom: bottomPosition,
      child: FutureBuilder<UserModel?>(
        future: _creatorFuture,
        builder: (context, snapshot) {
          final user = snapshot.data;
          return _InfoCard(
            video: widget.video,
            user: user,
            isLoading: snapshot.connectionState == ConnectionState.waiting,
            hashtags: hashtags,
            onProfileTap: widget.onProfileTap,
            onHashtagTap: widget.onHashtagTap,
          );
        },
      ),
      );
    });
  }

  List<String> _extractHashtags(String text) {
    final regex = RegExp(r'(#[\p{L}\d_]+)', unicode: true);
    final matches = regex.allMatches(text);
    final unique = <String>{};
    for (final match in matches) {
      final tag = match.group(0);
      if (tag != null && tag.length > 1) {
        unique.add(tag);
      }
    }
    return unique.take(5).toList();
  }

  VideoFeedController _resolveController() {
    if (Get.isRegistered<FollowersFeedController>()) {
      return Get.find<FollowersFeedController>();
    }
    return Get.find<VideoFeedController>();
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.video,
    required this.user,
    required this.isLoading,
    required this.hashtags,
    this.onProfileTap,
    this.onHashtagTap,
  });

  final VideoModel video;
  final UserModel? user;
  final bool isLoading;
  final List<String> hashtags;
  final VoidCallback? onProfileTap;
  final void Function(String hashtag)? onHashtagTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = _buildDisplayName();
    final username = _buildUsername();
    final caption = video.description.isNotEmpty ? video.description : video.title;
    final audioLabel = 'Original sound \u2022 ${displayName.isNotEmpty ? displayName : username}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, displayName, username),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                height: 1.3,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                shadows: [
                  const Shadow(
                    offset: Offset(0, 0),
                    blurRadius: 10,
                    color: Colors.black,
                  ),
                  const Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 4,
                    color: Colors.black,
                  ),
                  Shadow(
                    offset: const Offset(1, 1),
                    blurRadius: 2,
                    color: Colors.black.withOpacity(0.9),
                  ),
                ],
              ),
            ),
          ],
          if (hashtags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: hashtags
                  .map(
                    (tag) => GestureDetector(
                      onTap: onHashtagTap != null ? () => onHashtagTap!(tag) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.onPrimary.withOpacity(0.2),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            shadows: [
                              const Shadow(
                                offset: Offset(0, 0),
                                blurRadius: 6,
                                color: Colors.black,
                              ),
                              Shadow(
                                offset: const Offset(0, 1),
                                blurRadius: 2,
                                color: Colors.black.withOpacity(0.9),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.music_note,
                color: Colors.white.withOpacity(0.95),
                size: 16,
                shadows: const [
                  Shadow(
                    offset: Offset(0, 0),
                    blurRadius: 6,
                    color: Colors.black,
                  ),
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 3,
                    color: Colors.black,
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  audioLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    shadows: const [
                      Shadow(
                        offset: Offset(0, 0),
                        blurRadius: 6,
                        color: Colors.black,
                      ),
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  VideoFeedController _resolveController() {
    if (Get.isRegistered<FollowersFeedController>()) {
      return Get.find<FollowersFeedController>();
    }
    return Get.find<VideoFeedController>();
  }

  Widget _buildHeader(BuildContext context, String displayName, String username) {
    final controller = _resolveController();
    final authService = Get.find<AuthService>();
    final currentUser = authService.currentUser.value;
    final isOwnVideo = currentUser?.uid == video.ownerId;
    
    return GestureDetector(
      onTap: onProfileTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProfileAvatar(user: user, isLoading: isLoading),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              shadows: const [
                                Shadow(
                                  offset: Offset(0, 0),
                                  blurRadius: 10,
                                  color: Colors.black,
                                ),
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 4,
                                  color: Colors.black,
                                ),
                                Shadow(
                                  offset: Offset(1, 1),
                                  blurRadius: 2,
                                  color: Colors.black,
                                ),
                              ],
                            ) ??
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 0),
                                  blurRadius: 10,
                                  color: Colors.black,
                                ),
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 4,
                                  color: Colors.black,
                                ),
                                Shadow(
                                  offset: Offset(1, 1),
                                  blurRadius: 2,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PrivacyIndicator(privacy: video.privacy),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 0),
                        blurRadius: 8,
                        color: Colors.black,
                      ),
                      Shadow(
                        offset: const Offset(0, 1),
                        blurRadius: 3,
                        color: Colors.black,
                      ),
                      Shadow(
                        offset: const Offset(1, 1),
                        blurRadius: 2,
                        color: Colors.black.withOpacity(0.8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isOwnVideo && !isLoading) ...[
            const SizedBox(width: 12),
            Obx(() {
              final isFollowing = controller.isFollowingByUser[video.ownerId] ?? false;
              return GestureDetector(
                onTap: () => controller.toggleFollow(video.ownerId),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: isFollowing 
                        ? Colors.black.withOpacity(0.5)
                        : Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.7),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, 2),
                        blurRadius: 6,
                        color: Colors.black.withOpacity(0.4),
                      ),
                    ],
                  ),
                  child: Text(
                    isFollowing ? 'Following' : 'Follow',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.black.withOpacity(0.8),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _buildDisplayName() {
    if (isLoading) return 'Loading creator…';
    final name = user?.displayName ?? '';
    if (name.isNotEmpty) return name;
    return _fallbackLabel();
  }

  String _buildUsername() {
    if (isLoading) return '@…';
    final username = user?.username ?? '';
    if (username.isNotEmpty) return '@$username';
    return '@${_fallbackLabel()}';
  }

  String _fallbackLabel() {
    if (video.ownerId.isEmpty) return 'unknown';
    final sanitized = video.ownerId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    if (sanitized.length <= 16) return sanitized;
    return '${sanitized.substring(0, 12)}…';
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user, required this.isLoading});

  final UserModel? user;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final avatarWidget = _buildAvatarContent(context);
    
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.5),
        border: Border.all(
          color: Colors.white.withOpacity(0.8),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 2),
            blurRadius: 8,
            color: Colors.black.withOpacity(0.5),
          ),
        ],
      ),
      child: ClipOval(
        child: avatarWidget,
      ),
    );
  }

  Widget _buildAvatarContent(BuildContext context) {
    if (isLoading) {
      return Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
          ),
        ),
      );
    }

    final avatarUrl = user?.avatarUrl ?? '';
    if (avatarUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: avatarUrl,
        fit: BoxFit.cover,
        width: 44,
        height: 44,
        placeholder: (context, url) => Container(
          color: Colors.black.withOpacity(0.5),
          child: Center(
            child: Text(
              _initials(user?.displayName ?? user?.username ?? ''),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 3,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.black.withOpacity(0.5),
          child: Center(
            child: Text(
              _initials(user?.displayName ?? user?.username ?? ''),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 3,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.5),
      ),
      child: Center(
        child: Text(
          _initials(user?.displayName ?? user?.username ?? ''),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 3,
                color: Colors.black,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String value) {
    if (value.isEmpty) return '?';
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

class _PrivacyIndicator extends StatelessWidget {
  const _PrivacyIndicator({required this.privacy});

  final String? privacy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final IconData icon;
    final String tooltip;
    
    switch (privacy?.toLowerCase()) {
      case 'private':
        icon = Icons.lock;
        tooltip = 'Private';
        break;
      case 'followers-only':
        icon = Icons.people;
        tooltip = 'Followers only';
        break;
      case 'public':
      default:
        icon = Icons.public;
        tooltip = 'Public';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.only(top: 0),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 1),
              blurRadius: 4,
              color: Colors.black.withOpacity(0.4),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 16,
          color: Colors.white,
          shadows: const [
            Shadow(
              offset: Offset(0, 1),
              blurRadius: 3,
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }
}
