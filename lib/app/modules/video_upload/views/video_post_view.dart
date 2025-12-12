import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_opacity.dart';
import '../controllers/video_upload_controller.dart';

/// TikTok-style merged post-recording screen
/// - Video preview at top (50%)
/// - Metadata entry at bottom (50%)
class VideoPostView extends StatefulWidget {
  const VideoPostView({super.key});

  @override
  State<VideoPostView> createState() => _VideoPostViewState();
}

class _VideoPostViewState extends State<VideoPostView> {
  late final VideoUploadController _controller;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  VideoPlayerController? _videoPlayerController;
  Future<void>? _initializeFuture;
  Worker? _selectionWorker;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<VideoUploadController>();
    _titleController = TextEditingController(text: _controller.title.value);
    _descriptionController = TextEditingController(text: _controller.description.value);
    
    _titleController.addListener(() {
      _controller.title.value = _titleController.text;
    });
    _descriptionController.addListener(() {
      _controller.description.value = _descriptionController.text;
    });
    
    _selectionWorker = ever<XFile?>(_controller.selectedVideo, (_) {
      _initializePlayer();
    });
    _initializePlayer();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _selectionWorker?.dispose();
    _selectionWorker = null;
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    final selection = _controller.selectedVideo.value;
    if (selection == null) {
      await _videoPlayerController?.pause();
      if (mounted) {
        setState(() {
          _initializeFuture = null;
        });
      }
      return;
    }

    final newController = VideoPlayerController.file(File(selection.path));
    await _videoPlayerController?.dispose();

    setState(() {
      _videoPlayerController = newController;
      _initializeFuture = newController.initialize().then((_) {
        newController
          ..setLooping(true)
          ..play();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top bar: Close + Post button
                _TopBar(controller: _controller),
                
                // Video preview (50% of screen)
                Expanded(
                  flex: 5,
                  child: _VideoPreviewSection(
                    initializeFuture: _initializeFuture,
                    videoPlayerController: _videoPlayerController,
                    controller: _controller,
                  ),
                ),
                
                // Metadata entry (50% of screen)
                Expanded(
                  flex: 5,
                  child: _MetadataSection(
                    controller: _controller,
                    titleController: _titleController,
                    descriptionController: _descriptionController,
                  ),
                ),
              ],
            ),
            
            // Upload progress overlay
            Obx(() => _controller.isUploading.value
                ? _UploadProgressOverlay(controller: _controller)
                : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

// Top bar with Close and Post buttons
class _TopBar extends StatelessWidget {
  final VideoUploadController controller;

  const _TopBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2D3A) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.close, 
                color: isDark ? Colors.white : Colors.black87, 
                size: 24,
              ),
              onPressed: () async {
                final navigator = Navigator.of(context);
                await controller.resetSelection();
                if (navigator.canPop()) {
                  navigator.pop();
                }
              },
            ),
          ),
          
          // Title
          Text(
            'New Post',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          
          // Post button
          Obx(() {
            final isUploading = controller.isUploading.value;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isUploading ? null : controller.uploadVideo,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isUploading 
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                          ),
                    color: isUploading ? Colors.grey : null,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isUploading 
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Text(
                    isUploading ? 'Posting...' : 'Post',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// Video preview section (50% screen)
class _VideoPreviewSection extends StatelessWidget {
  final Future<void>? initializeFuture;
  final VideoPlayerController? videoPlayerController;
  final VideoUploadController controller;

  const _VideoPreviewSection({
    required this.initializeFuture,
    required this.videoPlayerController,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final videoFile = controller.selectedVideo.value;
      if (videoFile == null) {
        return Center(
          child: Text(
            'No video selected',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        );
      }
      
      if (initializeFuture == null) {
        return const Center(child: CircularProgressIndicator());
      }

      return FutureBuilder<void>(
        future: initializeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError || videoPlayerController == null) {
            return Center(
              child: Text(
                'Error loading video',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            );
          }
          
          return Stack(
            fit: StackFit.expand,
            children: [
              // Video player (looping)
              Center(
                child: AspectRatio(
                  aspectRatio: videoPlayerController!.value.aspectRatio,
                  child: VideoPlayer(videoPlayerController!),
                ),
              ),
              
              // Tap to play/pause
              GestureDetector(
                onTap: () {
                  if (videoPlayerController!.value.isPlaying) {
                    videoPlayerController!.pause();
                  } else {
                    videoPlayerController!.play();
                  }
                },
                child: Container(color: Colors.transparent),
              ),
              
              // Play icon overlay when paused
              Center(
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: videoPlayerController!,
                  builder: (context, value, child) {
                    if (!value.isPlaying && value.position > Duration.zero) {
                      return Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 40,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          );
        },
      );
    });
  }
}

// Metadata entry section (50% screen) with entrance animation
class _MetadataSection extends StatelessWidget {
  final VideoUploadController controller;
  final TextEditingController titleController;
  final TextEditingController descriptionController;

  const _MetadataSection({
    required this.controller,
    required this.titleController,
    required this.descriptionController,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? Colors.white.withOpacity(0.2)
                              : Colors.black.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    
                    // Title field
                    _TitleField(titleController: titleController),
                    const SizedBox(height: 20),
                    
                    // Description field
                    _DescriptionField(descriptionController: descriptionController),
                    const SizedBox(height: 20),
                    
                    // Hashtag chips
                    _HashtagField(controller: controller),
                    const SizedBox(height: 20),
                    
                    // Privacy selector
                    _PrivacyChips(controller: controller),
                    const SizedBox(height: 20),
                    
                    // Thumbnail selector
                    _ThumbnailSelector(controller: controller),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Title input field
class _TitleField extends StatelessWidget {
  final TextEditingController titleController;

  const _TitleField({required this.titleController});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.title,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Title',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D2D3A) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark 
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: titleController,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
            ),
            maxLength: 100,
            decoration: InputDecoration(
              hintText: 'Add a catchy title...',
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              filled: true,
              fillColor: Colors.transparent,
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
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              counterStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }
}

// Description input field
class _DescriptionField extends StatelessWidget {
  final TextEditingController descriptionController;

  const _DescriptionField({required this.descriptionController});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.description_outlined,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Description',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D2D3A) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark 
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: descriptionController,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
            ),
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Describe your video...',
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              filled: true,
              fillColor: Colors.transparent,
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
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              counterStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }
}

// Hashtag input field
class _HashtagField extends StatelessWidget {
  final VideoUploadController controller;

  const _HashtagField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.tag,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Hashtags',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Obx(() {
          final hashtags = controller.hashtags;
          return Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              ...hashtags.map((tag) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.primary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 4, top: 6, bottom: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tag,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => controller.removeHashtag(tag),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
              if (hashtags.length < 10)
                InkWell(
                  onTap: () => _showHashtagDialog(context, controller),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D2D3A) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark 
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.1),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          size: 18,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Add',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }

  void _showHashtagDialog(BuildContext context, VideoUploadController controller) {
    final textController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Get.dialog(
      AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D2D3A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Hashtag',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Enter hashtag (without #)',
            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
            prefixText: '#',
            prefixStyle: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
          ),
          FilledButton(
            onPressed: () {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                controller.addHashtagsFromInput('#$text');
                Get.back();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// Privacy selector chips
class _PrivacyChips extends StatelessWidget {
  final VideoUploadController controller;

  const _PrivacyChips({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.visibility_outlined,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Privacy',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Obx(() {
          final privacy = controller.selectedPrivacy.value;
          return Row(
            children: [
              Expanded(
                child: _PrivacyOption(
                  label: 'Public',
                  icon: Icons.public,
                  selected: privacy == VideoPrivacy.public,
                  onTap: () => controller.selectedPrivacy.value = VideoPrivacy.public,
                  isDark: isDark,
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PrivacyOption(
                  label: 'Friends',
                  icon: Icons.people,
                  selected: privacy == VideoPrivacy.friends,
                  onTap: () => controller.selectedPrivacy.value = VideoPrivacy.friends,
                  isDark: isDark,
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PrivacyOption(
                  label: 'Private',
                  icon: Icons.lock,
                  selected: privacy == VideoPrivacy.private,
                  onTap: () => controller.selectedPrivacy.value = VideoPrivacy.private,
                  isDark: isDark,
                  colorScheme: colorScheme,
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _PrivacyOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;
  final ColorScheme colorScheme;

  const _PrivacyOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.isDark,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: selected 
              ? LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withOpacity(0.8),
                  ],
                )
              : null,
          color: selected ? null : (isDark ? const Color(0xFF2D2D3A) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected 
                ? colorScheme.primary
                : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected 
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: selected 
                  ? Colors.white
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected 
                    ? Colors.white
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Upload progress overlay - Shows during upload with animations
class _UploadProgressOverlay extends StatelessWidget {
  final VideoUploadController controller;

  const _UploadProgressOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, fadeValue, child) {
        return Opacity(
          opacity: fadeValue,
          child: Container(
            color: Colors.black.withValues(alpha: AppOpacity.darkOverlay),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.8, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, scaleValue, child) {
                    return Transform.scale(
                      scale: scaleValue,
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                        padding: AppSpacing.allXxxl,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: AppOpacity.cardBackground),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: AppOpacity.overlayStrong),
                            width: 1.5,
                          ),
                          boxShadow: [
                            AppShadows.strong,
                            AppShadows.premiumGlow,
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Upload progress indicator with animation
                            Obx(() {
                              final progress = controller.uploadProgress.value;
                              return TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: progress),
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                builder: (context, animatedProgress, child) {
                                  return Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Outer glow effect
                                      Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context).colorScheme.primary.withValues(alpha: AppOpacity.overlayStrong),
                                              blurRadius: 20,
                                              spreadRadius: 5,
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Circular progress with gradient
                                      SizedBox(
                                        width: 100,
                                        height: 100,
                                        child: CircularProgressIndicator(
                                          value: animatedProgress,
                                          strokeWidth: 8,
                                          backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                      // Percentage text with animation
                                      TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 0.0, end: animatedProgress * 100),
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeOut,
                                        builder: (context, percentage, child) {
                                          return Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${percentage.toInt()}%',
                                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                                  color: const Color(0xFF1A1A2E),
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: -0.5,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            }),
                            const SizedBox(height: 28),
                            
                            // Status text with fade transition
                            Obx(() {
                              final progress = controller.uploadProgress.value;
                              String statusText;
                              IconData statusIcon;
                              
                              if (progress < 0.3) {
                                statusText = 'Uploading video...';
                                statusIcon = Icons.cloud_upload_outlined;
                              } else if (progress < 0.7) {
                                statusText = 'Processing...';
                                statusIcon = Icons.settings_outlined;
                              } else if (progress < 1.0) {
                                statusText = 'Almost done...';
                                statusIcon = Icons.check_circle_outline;
                              } else {
                                statusText = 'Finalizing...';
                                statusIcon = Icons.done_all;
                              }
                              
                              return TweenAnimationBuilder<double>(
                                key: ValueKey(statusText),
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                                builder: (context, fadeValue, child) {
                                  return Opacity(
                                    opacity: fadeValue,
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: AppSpacing.allMd,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            statusIcon,
                                            color: const Color(0xFF6C5CE7),
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          statusText,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            color: const Color(0xFF1A1A2E),
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.2,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }),
                            const SizedBox(height: 12),
                            
                            // Subtitle
                            Text(
                              'We\'re preparing your clip for streaming',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF4A4A5A),
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Thumbnail selector (horizontal scroll)
class _ThumbnailSelector extends StatelessWidget {
  final VideoUploadController controller;

  const _ThumbnailSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.photo_library, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              'Choose Thumbnail',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Obx(() {
          final thumbnails = controller.thumbnails;
          final selectedPath = controller.selectedThumbnailPath.value;
          
          if (thumbnails.isEmpty) {
            return Container(
              height: 120,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2D3A) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.orange.shade400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Generating thumbnails...',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          
          return SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: thumbnails.length,
              itemBuilder: (context, index) {
                final thumbnailPath = thumbnails[index];
                final isSelected = selectedPath != null && thumbnailPath == selectedPath;
                
                return Padding(
                  padding: EdgeInsets.only(right: AppSpacing.md),
                  child: GestureDetector(
                    onTap: () => controller.selectThumbnail(thumbnailPath),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? Colors.orange.shade400
                              : (isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300),
                          width: isSelected ? 3 : 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.3),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                        image: DecorationImage(
                          image: FileImage(File(thumbnailPath)),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: isSelected
                          ? Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.orange.withOpacity(0.3),
                                    Colors.deepOrange.withOpacity(0.5),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}
