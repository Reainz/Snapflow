import 'dart:math';
import 'dart:developer' as developer;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_shadows.dart';
import '../controllers/video_upload_controller.dart';

class VideoUploadView extends GetView<VideoUploadController> {
  const VideoUploadView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen camera preview
          _CameraPreview(controller: controller),
          
          // Top overlay: Close button + Recording timer
          _TopOverlay(controller: controller),
          
          // Side action bar: Flip, Flash, Filter, Effects
          _SideActionBar(controller: controller),
          
          // Countdown overlay (when timer is active) - MOVED BEFORE BUTTONS
          Obx(() => controller.isCountingDown.value
              ? _CountdownOverlay(controller: controller)
              : const SizedBox.shrink()),
          
          // Bottom center: TikTok-style recording button - NOW RENDERS LAST
          _BottomRecordingButton(controller: controller),
          
          // Bottom-left: Gallery thumbnail - NOW RENDERS LAST
          _GalleryThumbnail(controller: controller),
        ],
      ),
    );
  }
}

class _CameraPreview extends StatelessWidget {
  const _CameraPreview({required this.controller});

  final VideoUploadController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isReady = controller.isCameraInitialized.value;
      final camController = controller.cameraController;
      
      if (!isReady || camController == null) {
        return Container(
          color: Colors.black,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Opacity(
                    opacity: value,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: AppOpacity.lightOverlay),
                            shape: BoxShape.circle,
                          ),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.8, end: 1.2),
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeInOut,
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: const Icon(
                                  Icons.videocam_outlined,
                                  size: 64,
                                  color: Colors.white,
                                ),
                              );
                            },
                            onEnd: () {
                              // Repeat animation
                              if (!isReady) {
                                Future.delayed(Duration.zero, () {
                                  if (context.mounted) {
                                    (context as Element).markNeedsBuild();
                                  }
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Initializing camera...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }

      // Full-screen camera preview with filter
      return Obx(() {
        final filter = controller.getColorFilter();
        final cameraWidget = CameraPreview(camController);
        
        return filter != null
            ? ColorFiltered(
                colorFilter: filter,
                child: cameraWidget,
              )
            : cameraWidget;
      });
    });
  }
}

/// Top overlay with close button and recording timer - Enhanced with glassmorphism
class _TopOverlay extends StatelessWidget {
  const _TopOverlay({required this.controller});

  final VideoUploadController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Close button with glassmorphism - always visible
            _AnimatedButton(
                onTap: controller.handleCloseTap,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: AppOpacity.mediumOverlay),
                        Colors.white.withValues(alpha: AppOpacity.subtleOverlay),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: AppOpacity.overlayStrong),
                      width: 1.5,
                    ),
                    boxShadow: [AppShadows.medium],
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              
              // Recording timer - always visible when recording
              _RecordingTimerWidget(controller: controller),
            ],
          ),
        ),
    );
  }
}

/// Recording timer with pulse animation - Enhanced with glassmorphism
class _RecordingTimerWidget extends StatelessWidget {
  const _RecordingTimerWidget({required this.controller});

  final VideoUploadController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isRecording = controller.isRecording.value;
      final duration = controller.recordingDuration.value;
      
      if (!isRecording && duration == Duration.zero) {
        return const SizedBox.shrink();
      }
      
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: isRecording ? 1.05 : 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                gradient: isRecording
                    ? LinearGradient(
                        colors: [
                          Colors.red.shade600,
                          Colors.red.shade700,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: AppOpacity.lightOverlay),
                          Colors.white.withValues(alpha: AppOpacity.subtleOverlay),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isRecording
                      ? Colors.red.shade300.withValues(alpha: AppOpacity.overlayIntense)
                      : Colors.white.withValues(alpha: AppOpacity.overlayStrong),
                  width: 1.5,
                ),
                boxShadow: isRecording
                    ? [
                        AppShadows.recording,
                        AppShadows.light,
                      ]
                    : [AppShadows.light],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isRecording)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      builder: (context, opacity, child) {
                        return AnimatedOpacity(
                          opacity: opacity,
                          duration: const Duration(milliseconds: 800),
                          child: Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [AppShadows.light],
                            ),
                          ),
                        );
                      },
                    ),
                  Text(
                    _formatDuration(duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                      shadows: [
                        Shadow(
                          color: Colors.black26,
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
        },
      );
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// Side action bar with Flip, Flash, Filter, Effects buttons
class _SideActionBar extends StatelessWidget {
  const _SideActionBar({required this.controller});

  final VideoUploadController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).size.height * 0.35,
      child: Column(
        children: [
              // Flip camera button with loading state
              Obx(() {
                final isSwitching = controller.isSwitchingCamera.value;
                final isRecording = controller.isRecording.value;
                final cameraCount = controller.cameras.length;
                final canSwitch = cameraCount > 1 && !isSwitching && !isRecording;
                
                return _AnimatedSideButton(
                  child: _SideActionButton(
                    icon: isSwitching ? Icons.hourglass_top : Icons.cameraswitch,
                    onTap: canSwitch
                        ? () {
                            developer.log('👆 [Camera Switch] Button tapped - calling switchCamera()', name: 'VideoUpload');
                            controller.switchCamera();
                          }
                        : null,
                    isActive: isSwitching,
                  ),
                );
              }),
              const SizedBox(height: 20),
              
              // Flash button - Using bolt icon for better distinction
              Obx(() {
                final mode = controller.flashMode.value;
                IconData icon;
                switch (mode) {
                  case FlashMode.off:
                    icon = Icons.bolt_outlined;
                    break;
                  case FlashMode.torch:
                    icon = Icons.bolt;
                    break;
                  case FlashMode.auto:
                  case FlashMode.always:
                    icon = Icons.bolt;
                    break;
                }
                
                return _AnimatedSideButton(
                  child: _SideActionButton(
                    icon: icon,
                    onTap: controller.cycleFlashMode,
                    isActive: mode != FlashMode.off,
                  ),
                );
              }),
              const SizedBox(height: 20),
              
              // Filter button - Using palette icon for better distinction
              Obx(() {
                final hasFilter = controller.selectedFilter.value != CameraFilter.none;
                return _AnimatedSideButton(
                  child: _SideActionButton(
                    icon: hasFilter ? Icons.palette : Icons.palette_outlined,
                    onTap: () => _showFilterPicker(context),
                    isActive: hasFilter,
                  ),
                );
              }),
              // Removed "Coming Soon" effects button - will be added when feature is ready
            ],
          ),
    );
  }

  void _showFilterPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _FilterPickerSheet(controller: controller),
    );
  }
}

/// Side action button widget - Enhanced with glassmorphism
class _SideActionButton extends StatelessWidget {
  const _SideActionButton({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: isActive
            ? LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: AppOpacity.overlayMedium),
                  Colors.white.withValues(alpha: AppOpacity.subtleOverlay),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: AppOpacity.overlayHeavy)
              : Colors.white.withValues(alpha: AppOpacity.overlayStandard),
          width: 1.5,
        ),
        boxShadow: isActive
            ? [
                AppShadows.activeFilter,
                AppShadows.light,
              ]
            : [AppShadows.light],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap != null 
              ? () {
                  developer.log('🎯 [InkWell] Tap detected - calling onTap callback', name: 'VideoUpload');
                  onTap!();
                }
              : () {
                  developer.log('🚫 [InkWell] Tap detected but onTap is null (button disabled)', name: 'VideoUpload');
                },
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
              shadows: const [
                Shadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated wrapper for side buttons with scale effect
class _AnimatedSideButton extends StatefulWidget {
  const _AnimatedSideButton({required this.child});

  final Widget child;

  @override
  State<_AnimatedSideButton> createState() => _AnimatedSideButtonState();
}

class _AnimatedSideButtonState extends State<_AnimatedSideButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use Listener to detect tap events without blocking them
    return Listener(
      onPointerDown: (_) => _controller.forward(),
      onPointerUp: (_) => _controller.reverse(),
      onPointerCancel: (_) => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Bottom center recording button (TikTok-style) - Enhanced with better shadows
class _BottomRecordingButton extends StatelessWidget {
  const _BottomRecordingButton({required this.controller});

  final VideoUploadController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      // Keep the button above any parent BottomNavigationBar by offsetting
      // with kBottomNavigationBarHeight plus an extra margin.
      bottom: MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 24,
      left: 0,
      right: 0,
      child: Center(
        child: Obx(() {
          final isRecording = controller.isRecording.value;
          // Only disable button when actively toggling recording or switching cameras
          // Don't disable when camera is not initialized - let user tap to retry
          final isBusy = controller.isTogglingRecording.value || controller.isSwitchingCamera.value;
          
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isBusy
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    // Use unified toggle with debounce guard
                    controller.toggleRecording();
                  },
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  AppShadows.largeCircle,
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Animated progress ring during recording
                  if (isRecording) _RecordingProgressRing(controller: controller),
                  
                  // Outer white ring with shadow
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 5.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: AppOpacity.overlayStrong),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  
                  // Inner circle/square (red button) with gradient
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: isRecording
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFFEF4444), // red-500
                                  Color(0xFFDC2626), // red-600
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.red.shade400,
                                  Colors.red.shade500,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        shape: isRecording ? BoxShape.rectangle : BoxShape.circle,
                        borderRadius: isRecording ? BorderRadius.circular(10) : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: AppOpacity.overlayHeavy),
                            blurRadius: isRecording ? 16 : 8,
                            spreadRadius: isRecording ? 1 : 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Optional busy overlay to give subtle visual feedback (reduced opacity)
                  if (isBusy)
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: AppOpacity.lightOverlay),
                        border: Border.all(color: Colors.white.withValues(alpha: AppOpacity.lightOverlay)),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Gallery thumbnail preview (bottom-left) - Enhanced with glassmorphism
class _GalleryThumbnail extends StatelessWidget {
  const _GalleryThumbnail({required this.controller});

  final VideoUploadController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      // Keep the gallery button above any BottomNavigationBar as well
      bottom: MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 24,
      left: 24,
      child: Obx(() {
        final video = controller.selectedVideo.value;
        
        return GestureDetector(
          onTap: controller.pickVideoFromGallery,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: AppOpacity.overlayMedium),
                  Colors.white.withValues(alpha: AppOpacity.subtleOverlay),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: AppOpacity.overlayStandard),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: AppOpacity.overlayStrong),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: video != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Icon(
                      Icons.videocam,
                      color: Colors.white,
                      size: 32,
                      shadows: const [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  )
                : Icon(
                    Icons.video_library_rounded,
                    color: Colors.white,
                    size: 32,
                    shadows: const [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
          ),
        );
      }),
    );
  }
}

/// Countdown timer overlay - Enhanced with better animations
class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.controller});

  final VideoUploadController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: AppOpacity.overlayVeryDark),
            Colors.black.withValues(alpha: AppOpacity.overlayDark),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Obx(() {
          final remaining = controller.countdownRemaining.value;
          return TweenAnimationBuilder<double>(
            key: ValueKey(remaining), // Force rebuild on change
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Countdown number with glow effect
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: AppOpacity.overlayLight),
                            Colors.transparent,
                          ],
                          stops: const [0.5, 1.0],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          remaining.toString(),
                          style: TextStyle(
                            fontSize: 140,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.white.withValues(alpha: AppOpacity.overlayHeavy),
                                blurRadius: 30,
                              ),
                              const Shadow(
                                color: Colors.black54,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Cancel button with glassmorphism
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: controller.cancelCountdown,
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: AppOpacity.mediumOverlay),
                                Colors.white.withValues(alpha: AppOpacity.lightOverlay),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: AppOpacity.overlayStrong),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 24,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// Filter picker bottom sheet - Enhanced with modern design
class _FilterPickerSheet extends StatelessWidget {
  const _FilterPickerSheet({required this.controller});

  final VideoUploadController controller;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 200),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black.withValues(alpha: 0.85),
              Colors.grey.shade900.withValues(alpha: 0.92),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 8,
              offset: const Offset(0, -4),
            ),
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        child: Column(
          children: [
            // Title with gradient
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [Colors.white, Theme.of(context).colorScheme.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Text(
                      'Filters',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Horizontal filter carousel with error boundary
            Expanded(
              child: Builder(
                builder: (context) {
                  try {
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      physics: const BouncingScrollPhysics(),
                      itemCount: CameraFilter.values.length,
                      itemBuilder: (context, index) {
                        try {
                          return _FilterPreviewCard(
                            controller: controller,
                            filter: CameraFilter.values[index],
                            index: index,
                          );
                        } catch (e) {
                          debugPrint('⚠️ Error building filter card $index: $e');
                          return const SizedBox.shrink();
                        }
                      },
                    );
                  } catch (e) {
                    debugPrint('⚠️ Error building filter list: $e');
                    return const Center(
                      child: Text(
                        'Unable to load filters',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPreviewCard extends StatelessWidget {
  const _FilterPreviewCard({
    required this.controller,
    required this.filter,
    required this.index,
  });

  final VideoUploadController controller;
  final CameraFilter filter;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 250 + (index * 60)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.5 + (value * 0.5),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Obx(() {
        final isSelected = controller.selectedFilter.value == filter;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            controller.selectFilter(filter);
            Navigator.pop(context);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  width: isSelected ? 76 : 70,
                  height: isSelected ? 76 : 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _getFilterGradient(filter),
                    border: Border.all(
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white.withValues(alpha: AppOpacity.lightOverlay),
                      width: isSelected ? 3.5 : 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                              blurRadius: 18,
                              spreadRadius: 3,
                            ),
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                              blurRadius: 28,
                              spreadRadius: 6,
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                  ),
                  child: Center(
                    child: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 28,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: TextStyle(
                    fontSize: isSelected ? 14 : 12.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.85),
                    shadows: isSelected
                        ? [
                            Shadow(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    filter.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  LinearGradient _getFilterGradient(CameraFilter filter) {
    switch (filter) {
      case CameraFilter.none:
        return const LinearGradient(
          colors: [Colors.white, Colors.grey],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CameraFilter.warm:
        return const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CameraFilter.cool:
        return const LinearGradient(
          colors: [Color(0xFF4ECDC4), Color(0xFF556270)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CameraFilter.vintage:
        return const LinearGradient(
          colors: [Color(0xFFD4A373), Color(0xFF8B7355)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CameraFilter.blackAndWhite:
        return const LinearGradient(
          colors: [Colors.black, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CameraFilter.sepia:
        return const LinearGradient(
          colors: [Color(0xFF704214), Color(0xFFC9A961)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CameraFilter.vivid:
        return const LinearGradient(
          colors: [Color(0xFFFF0080), Color(0xFF7928CA), Color(0xFF00DFD8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CameraFilter.dramatic:
        return const LinearGradient(
          colors: [Color(0xFF1a1a1a), Color(0xFF8B0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }
}

/// Recording progress ring widget
class _RecordingProgressRing extends StatelessWidget {
  const _RecordingProgressRing({required this.controller});

  final VideoUploadController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final duration = controller.recordingDuration.value;
      const maxDuration = Duration(seconds: 60); // 60s max
      final progress = duration.inMilliseconds / maxDuration.inMilliseconds;
      
      return CustomPaint(
        size: const Size(80, 80),
        painter: _ProgressRingPainter(
          progress: progress.clamp(0.0, 1.0),
          color: Colors.red,
          strokeWidth: 5,
        ),
      );
    });
  }
}

/// Custom painter for the recording progress ring
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const startAngle = -pi / 2; // Start from top
    final sweepAngle = 2 * pi * progress;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Animated button wrapper with scale animation
class _AnimatedButton extends StatefulWidget {
  const _AnimatedButton({
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap(); // Actually invoke the callback
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
