import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../data/models/comment_model.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../routes/app_routes.dart';

class CommentItemWidget extends StatefulWidget {
  final CommentModel comment;
  final bool isOwn;
  final RxBool? isLiked;
  final RxInt? likeCount;
  final VoidCallback onLike;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CommentItemWidget({
    super.key,
    required this.comment,
    required this.isOwn,
    this.isLiked,
    this.likeCount,
    required this.onLike,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<CommentItemWidget> createState() => _CommentItemWidgetState();
}

class _CommentItemWidgetState extends State<CommentItemWidget> {
  final UserRepository _userRepository = Get.find<UserRepository>();
  String? _username;
  String? _avatarUrl;
  bool _isLoadingUsername = true;

  @override
  void initState() {
    super.initState();
    _fetchUsername();
  }

  Future<void> _fetchUsername() async {
    try {
      final user = await _userRepository.getUserById(widget.comment.authorId);
      if (mounted) {
        setState(() {
          _username = user.username;
          _avatarUrl = user.avatarUrl;
          _isLoadingUsername = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _username = 'Unknown User';
          _avatarUrl = null;
          _isLoadingUsername = false;
        });
      }
    }
  }

  String _getTimeAgo() {
    try {
      return timeago.format(widget.comment.createdAt, locale: 'en_short');
    } catch (e) {
      return 'just now';
    }
  }

  void _openAuthorProfile() {
    if (widget.comment.authorId.isEmpty) return;
    Get.toNamed(
      Routes.profile,
      arguments: {'userId': widget.comment.authorId},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: InkWell(
          onTap: _openAuthorProfile,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                  ? NetworkImage(_avatarUrl!)
                  : null,
              child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                  ? Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    )
                  : null,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _openAuthorProfile,
              child: Row(
                children: [
                  if (_isLoadingUsername)
                    const SizedBox(
                      width: 80,
                      height: 12,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                      ),
                    )
                  else
                    Text(
                      _username ?? 'Unknown User',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    '\u2022 ${_getTimeAgo()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.comment.text,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isLiked != null && widget.likeCount != null)
              Obx(() {
                final isLiked = widget.isLiked!.value;
                final count = widget.likeCount!.value;

                return InkWell(
                  onTap: widget.onLike,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isLiked
                          ? Colors.red.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: isLiked ? Colors.red : Colors.grey[600],
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isLiked ? Colors.red : Colors.grey[700],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            if (widget.isOwn) ...[
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[600]),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.blue, size: 20),
                        SizedBox(width: 12),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 12),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    widget.onEdit();
                  } else if (value == 'delete') {
                    widget.onDelete();
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

