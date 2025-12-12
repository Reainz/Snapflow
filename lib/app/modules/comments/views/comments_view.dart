import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_opacity.dart';
import '../controllers/comments_controller.dart';
import '../widgets/comment_item_widget.dart';

class CommentsView extends GetView<CommentsController> {
  const CommentsView({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController textController = TextEditingController();
    final FocusNode focusNode = FocusNode();

    // Hide emoji picker when text field is focused
    focusNode.addListener(() {
      if (focusNode.hasFocus && controller.showEmojiPicker.value) {
        controller.hideEmojiPicker();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Comments',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(
              () {
                // Show loading spinner while loading
                if (controller.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                
                // Show empty state only after loading is complete
                if (controller.comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No comments yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to comment!',
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
                  duration: AppDurations.standard,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: controller.comments.length,
                    itemBuilder: (_, index) {
                      final c = controller.comments[index];
                      final isOwn = controller.isOwnComment(c.authorId);
                      
                      return _AnimatedCommentCard(
                        child: CommentItemWidget(
                      comment: c,
                      isOwn: isOwn,
                      isLiked: controller.commentLikedStates[c.id],
                      likeCount: controller.commentLikeCounts[c.id],
                      onLike: () => controller.toggleLike(c.id),
                        onEdit: () => controller.showEditDialog(c),
                        onDelete: () => controller.deleteComment(c.id),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        // Emoji Picker
          Obx(() {
            if (!controller.showEmojiPicker.value) {
              return const SizedBox.shrink();
            }
            
            return SizedBox(
              height: 250,
              child: EmojiPicker(
                textEditingController: textController,
                config: Config(
                  height: 256,
                  emojiViewConfig: EmojiViewConfig(
                    columns: 7,
                    emojiSizeMax: 28,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  ),
                  searchViewConfig: SearchViewConfig(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    iconColorSelected: Theme.of(context).colorScheme.primary,
                  ),
                  bottomActionBarConfig: BottomActionBarConfig(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  ),
                ),
              ),
            );
          }),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Emoji button
                Obx(() => IconButton(
                  onPressed: () {
                    if (focusNode.hasFocus) {
                      focusNode.unfocus();
                      Future.delayed(const Duration(milliseconds: 100), () {
                        controller.toggleEmojiPicker();
                      });
                    } else {
                      controller.toggleEmojiPicker();
                    }
                  },
                  icon: Icon(
                    controller.showEmojiPicker.value
                        ? Icons.keyboard
                        : Icons.emoji_emotions_outlined,
                    color: controller.showEmojiPicker.value
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  iconSize: 26,
                )),
                const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    elevation: 1,
                    borderRadius: BorderRadius.circular(16),
                    child: TextField(
                      controller: textController,
                      focusNode: focusNode,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  elevation: 3,
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                  shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                  child: IconButton(
                    onPressed: () async {
                      final text = textController.text.trim();
                      if (text.isEmpty || controller.isSending.value) return;
                      await controller.sendComment(text);
                      textController.clear();
                      controller.hideEmojiPicker();
                    },
                    icon: Icon(
                      Icons.send,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Animated comment card for tap scale feedback
class _AnimatedCommentCard extends StatefulWidget {
  final Widget child;

  const _AnimatedCommentCard({required this.child});

  @override
  State<_AnimatedCommentCard> createState() => _AnimatedCommentCardState();
}

class _AnimatedCommentCardState extends State<_AnimatedCommentCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: AppDurations.micro,
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}
