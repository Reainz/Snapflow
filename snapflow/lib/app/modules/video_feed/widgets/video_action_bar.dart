import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/video_model.dart';
import '../../followers_feed/controllers/followers_feed_controller.dart';
import '../controllers/video_feed_controller.dart';

class VideoActionBar extends StatefulWidget {
  const VideoActionBar({
    super.key,
    required this.video,
    this.onProfileTap,
    this.onLikeTap,
    this.onCommentTap,
    this.onShareTap,
    this.onBookmarkTap,
    this.onFlagTap,
  });

  final VideoModel video;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onFlagTap;

  @override
  State<VideoActionBar> createState() => _VideoActionBarState();
}

class _VideoActionBarState extends State<VideoActionBar> {
  @override
  Widget build(BuildContext context) {
    final feed = _feedController();
    return Positioned(
      right: 12,
      bottom: 110,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Obx(() {
                final isLiked = feed.isLikedByVideo[widget.video.id] ?? widget.video.isLiked;
                final likes = feed.likesCountByVideo[widget.video.id] ?? widget.video.likesCount;
                return _ActionButton(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  activeColor: Colors.redAccent,
                  isActive: isLiked,
                  label: _formatCount(likes),
                  onTap: widget.onLikeTap,
                );
              }),
              const SizedBox(height: 16),
              Obx(() {
                final comments = feed.commentsCountByVideo[widget.video.id] ?? widget.video.commentsCount;
                return _ActionButton(
                  icon: Icons.mode_comment_outlined,
                  label: _formatCount(comments),
                  onTap: widget.onCommentTap,
                );
              }),
              const SizedBox(height: 16),
              _ActionButton(
                icon: Icons.more_horiz,
                label: 'More',
                onTap: () => _showMoreOptions(context),
              ),
            ],
          ),
    );
  }

  VideoFeedController _feedController() {
    if (Get.isRegistered<FollowersFeedController>()) {
      return Get.find<FollowersFeedController>();
    }
    return Get.find<VideoFeedController>();
  }

  void _showMoreOptions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final feed = _feedController();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Obx(() {
          final saved = feed.isSavedByVideo[widget.video.id] ?? false;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  'More Options',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              _MoreOptionTile(
                icon: Icons.share_rounded,
                title: 'Share',
                subtitle: 'Share this video with friends',
                iconColor: Colors.blue.shade400,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(context);
                  widget.onShareTap?.call();
                },
              ),
              _MoreOptionTile(
                icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                title: saved ? 'Unsave' : 'Save',
                subtitle: saved ? 'Remove from saved videos' : 'Save video to watch later',
                iconColor: Colors.amber.shade600,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(context);
                  widget.onBookmarkTap?.call();
                },
              ),
              _MoreOptionTile(
                icon: Icons.flag_rounded,
                title: 'Report',
                subtitle: 'Report inappropriate content',
                iconColor: Colors.red.shade400,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(context);
                  widget.onFlagTap?.call();
                },
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          );
        }),
      ),
    );
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${_trimTrailingZeros((value / 1000000).toStringAsFixed(1))}M';
    }
    if (value >= 1000) {
      return '${_trimTrailingZeros((value / 1000).toStringAsFixed(1))}K';
    }
    return value.toString();
  }

  String _trimTrailingZeros(String value) {
    return value.endsWith('.0') ? value.substring(0, value.length - 2) : value;
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isActive = false,
    this.activeColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;
  final Color? activeColor;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  double _scale = 1.0;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      Get.log('_ActionButton tapDown for ${widget.label}');
      setState(() => _scale = 0.92);
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null) {
      Get.log('_ActionButton tapCancel for ${widget.label}');
      setState(() => _scale = 1.0);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      Get.log('_ActionButton tapUp for ${widget.label}, calling onTap');
      setState(() => _scale = 1.0);
      widget.onTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive 
        ? (widget.activeColor ?? Colors.white) 
        : Colors.white;
    
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapCancel: _handleTapCancel,
      onTapUp: _handleTapUp,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isActive 
                      ? (widget.activeColor ?? Colors.white).withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: (widget.activeColor ?? Colors.white).withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeInBack,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: Icon(
                  widget.icon,
                  key: ValueKey('${widget.icon}_${widget.isActive}'),
                  color: color,
                  size: 26,
                  shadows: const [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: const [
                  Shadow(
                    color: Colors.black87,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreOptionTile extends StatelessWidget {
  const _MoreOptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor,
    this.isDark = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (iconColor ?? Colors.grey).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? (isDark ? Colors.white : Colors.black87),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
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
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
