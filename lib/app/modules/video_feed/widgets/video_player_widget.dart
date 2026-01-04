import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:subtitle/subtitle.dart';

import '../../../data/models/video_model.dart';
import '../../followers_feed/controllers/followers_feed_controller.dart';
import '../controllers/video_feed_controller.dart';
import '../../video_upload/controllers/video_upload_controller.dart';

class VideoPlayerWidget extends StatefulWidget {
  const VideoPlayerWidget({
    super.key,
    required this.video,
    required this.isActive,
    this.onDoubleTap,
  });

  final VideoModel video;
  final bool isActive;
  final VoidCallback? onDoubleTap;

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  late final RxBool _isPlaying;
  late final RxBool _isMuted;
  late final RxBool _isBuffering;
  late final RxDouble _positionMs;
  late final RxDouble _durationMs;
  bool _initializationFailed = false;
  bool _signedUrlRetryRequested = false;
  int _retryAttempt = 0;
  static const int _maxRetries = 3;
  static const List<int> _retryDelaysMs = [1000, 2000, 4000];
  
  // Caption state
  List<Subtitle> _subtitles = [];
  String _currentCaption = '';

  bool get _hasVideoSource => widget.video.hlsUrl.isNotEmpty;
  
  // Expose playing state for external widgets
  RxBool get isPlaying => _isPlaying;

  @override
  void initState() {
    super.initState();
    _isPlaying = false.obs;
    _isMuted = false.obs;
    _isBuffering = false.obs;
    _positionMs = 0.0.obs;
    _durationMs = 1.0.obs;
    _initializeController();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id ||
        oldWidget.video.hlsUrl != widget.video.hlsUrl) {
      _signedUrlRetryRequested = false;
      _retryAttempt = 0;
      _initializationFailed = false;
      _initializeController();
    } else if (oldWidget.isActive != widget.isActive) {
      _updatePlaybackState();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _initializeController() {
    _disposeController();

    // Reset failure marker for this initialization attempt (retry counter persists across retries)
    _initializationFailed = false;

    if (!_hasVideoSource) {
      _initializationFailed = true;
      _initializeFuture = null;
      setState(() {});
      return;
    }

    final parsedUri = Uri.tryParse(widget.video.hlsUrl);
    if (parsedUri == null) {
      _initializationFailed = true;
      _initializeFuture = null;
      setState(() {});
      return;
    }

    // Use HLS format hint for .m3u8 playback
    // Reduce buffer to prevent ImageReader warnings
    final controller = VideoPlayerController.networkUrl(
      parsedUri,
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      ),
      formatHint: VideoFormat.hls,
    );
    _controller = controller;
    _initializationFailed = false;

    _initializeFuture = controller.initialize().then((_) {
      if (!mounted) return;
      controller
        ..setLooping(true)
        ..setVolume(_isMuted.value ? 0 : 1);
      final initialDuration = controller.value.duration.inMilliseconds.toDouble();
      _durationMs.value = initialDuration > 0 ? initialDuration : 1.0;
      _listenToController();
      _updatePlaybackState();
      
      // Load captions if available
      if (widget.video.hasCaptions) {
        _loadCaptions();
      }
      
      // Clear any prior error for this video on successful init
      final feedController = _feedControllerOptional();
      feedController?.videoUrlSigningErrors.remove(widget.video.id);

      setState(() {});
    }).catchError((Object error, StackTrace stackTrace) async {
      Get.log(
        'Failed to initialize video ${widget.video.id} (attempt ${_retryAttempt + 1}): $error',
        isError: true,
      );
      Get.log('Error type: ${error.runtimeType}, Error details: $stackTrace', isError: true);
      if (!mounted) return;

      final feedController = _feedControllerOptional();
      final friendlyMessage = _userFriendlyMessageFromError(error);
      feedController?.videoUrlSigningErrors[widget.video.id] = friendlyMessage;

      // If this is a private/followers-only video, force a re-sign on the first failure.
      if (_retryAttempt == 0 && !_signedUrlRetryRequested) {
        _signedUrlRetryRequested = true;
        try {
          await feedController?.refreshSignedUrlIfNeeded(widget.video.id, force: true);
        } catch (e) {
          Get.log('URL refresh failed during retry for ${widget.video.id}: $e');
        }
      }

      // Exponential backoff retry
      if (_retryAttempt < _maxRetries) {
        final delayMs = _retryDelaysMs[_retryAttempt];
        _retryAttempt++;
        await Future.delayed(Duration(milliseconds: delayMs));
        _initializeController();
        return;
      }

      _initializationFailed = true;
      _retryAttempt = 0;
      setState(() {});
    });
  }

  void _listenToController() {
    final controller = _controller;
    if (controller == null) return;
    controller
      ..removeListener(_handleControllerUpdate)
      ..addListener(_handleControllerUpdate);
    _handleControllerUpdate();
  }

  void _handleControllerUpdate() {
    final controller = _controller;
    if (controller == null) return;
    final value = controller.value;
    _isBuffering.value = value.isBuffering || !value.isInitialized;
    if (value.isInitialized) {
      final durationMs = value.duration.inMilliseconds.toDouble();
      if (durationMs > 0) {
        _durationMs.value = durationMs;
      }
      _positionMs.value = value.position.inMilliseconds.toDouble().clamp(0.0, _durationMs.value);
      
      // Update current caption based on video position
      _updateCurrentCaption(value.position);
    }
    _isPlaying.value = value.isPlaying && !value.isBuffering;
  }

  void _disposeController() {
    final controller = _controller;
    if (controller != null) {
      controller
        ..removeListener(_handleControllerUpdate)
        ..pause()
        ..dispose();
    }
    _controller = null;
    _initializeFuture = null;
    _isPlaying.value = false;
    _isBuffering.value = false;
    _positionMs.value = 0;
  }

  void _updatePlaybackState() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (widget.isActive) {
      // Small delay to allow buffer cleanup before starting new video
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _controller == controller && widget.isActive) {
          controller.play();
        }
      });
    } else {
      // Pause immediately when not active to free buffers
      controller.pause();
    }
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  void _toggleMute() {
    final controller = _controller;
    if (controller == null) return;
    final nextMuted = !_isMuted.value;
    _isMuted.value = nextMuted;
    controller.setVolume(nextMuted ? 0 : 1);
  }

  void _seekTo(double value) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final position = Duration(milliseconds: value.round());
    controller.seekTo(position);
  }

  Future<void> _loadCaptions() async {
    if (!widget.video.hasCaptions || widget.video.captionUrl == null || widget.video.captionUrl!.isEmpty) {
      _subtitles = [];
      _currentCaption = '';
      return;
    }

    try {
      final uri = Uri.tryParse(widget.video.captionUrl!);
      if (uri == null) return;

      final response = await http.get(uri);
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final subtitleObject = SubtitleObject(
          data: response.body,
          type: SubtitleType.vtt,
        );
        final parser = SubtitleParser(subtitleObject);
        _subtitles = parser.parsing();
        Get.log('Loaded ${_subtitles.length} captions for video ${widget.video.id}');
      }
    } catch (e) {
      Get.log('Failed to load captions: $e', isError: true);
      _subtitles = [];
    }
  }

  void _updateCurrentCaption(Duration position) {
    if (_subtitles.isEmpty) {
      if (_currentCaption.isNotEmpty) {
        setState(() {
          _currentCaption = '';
        });
      }
      return;
    }

    // Find the subtitle that matches current position
    final currentSubtitle = _subtitles.firstWhereOrNull(
      (subtitle) =>
          position >= subtitle.start &&
          position <= subtitle.end,
    );

    final newCaption = currentSubtitle?.data ?? '';
    if (newCaption != _currentCaption) {
      setState(() {
        _currentCaption = newCaption;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _feedControllerOptional();

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildVideoLayer(),

        if (controller != null)
          Obx(() {
            final signingError = controller.videoUrlSigningErrors[widget.video.id];
            if (signingError == null) return const SizedBox.shrink();
            return _buildSigningErrorOverlay(signingError, controller);
          }),

        // GestureDetector for play/pause in the center area only
        Positioned.fill(
          child: GestureDetector(
            onTap: _togglePlayPause,
            onDoubleTap: widget.onDoubleTap,
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),
        ),
        _buildBufferingIndicator(),
        _buildPlayPauseOverlay(),
        _buildMuteButton(context),
        _buildCaptionButton(context),
        _buildCaptionOverlay(context),
        _buildProgressBar(context),
      ],
    );
  }

  Widget _buildVideoLayer() {
    if (!_hasVideoSource) {
      return _buildThumbnail(fallback: true);
    }

    final controller = _controller;
    if (_initializeFuture == null || controller == null) {
      return _buildThumbnail();
    }

    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            controller.value.isInitialized &&
            !_initializationFailed) {
          // Get filter from video metadata
          final filter = VideoUploadController.getColorFilterFromName(
            widget.video.filterUsed,
          );
          
          final videoPlayer = VideoPlayer(controller);
          
          return FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: filter != null
                  ? ColorFiltered(
                      colorFilter: filter,
                      child: videoPlayer,
                    )
                  : videoPlayer,
            ),
          );
        }

        if (snapshot.hasError || _initializationFailed) {
          return _buildThumbnail(fallback: true);
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            _buildThumbnail(),
            Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThumbnail({bool fallback = false}) {
    if (widget.video.thumbnailUrl.isEmpty || fallback) {
      return Container(color: Colors.black87);
    }

    return CachedNetworkImage(
      imageUrl: widget.video.thumbnailUrl,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
      placeholder: (context, url) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'Thumbnail unavailable',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBufferingIndicator() {
    return Obx(() {
      if (!_isBuffering.value) return const SizedBox.shrink();
      return Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary),
        ),
      );
    });
  }

  Widget _buildSigningErrorOverlay(String errorMessage, VideoFeedController? controller) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 56),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () => _handleRetryFromError(controller),
                icon: const Icon(Icons.refresh),
                label: const Text('Tap to retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPauseOverlay() {
    return Obx(() {
      // Only show play icon when video is actually paused (not loading/buffering)
      // Controller must be initialized so we know it's a true pause state
      final isInitialized = _controller?.value.isInitialized ?? false;
      final show = !_isPlaying.value && !_isBuffering.value && isInitialized;
      return IgnorePointer(
        ignoring: true, // purely visual overlay so taps reach the gesture detector below
        child: AnimatedOpacity(
          opacity: show ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 48,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildMuteButton(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 44,
      right: 16,
      child: Obx(() {
        final isMuted = _isMuted.value;
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _toggleMute,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Icon(
                    isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 24,
                    shadows: const [
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCaptionButton(BuildContext context) {
    // Captions aren't supported reliably in the current thesis demo build.
    // Hide the CC toggle button to avoid confusing users.
    return const SizedBox.shrink();
  }

  Widget _buildCaptionOverlay(BuildContext context) {
    final controller = _feedControllerOptional();
    if (controller == null) return const SizedBox.shrink();
    
    return Obx(() {
      // Only show captions if enabled and there's text to display
      if (!controller.showCaptions.value || 
          _currentCaption.isEmpty ||
          !widget.video.hasCaptions) {
        return const SizedBox.shrink();
      }
      
      return Positioned(
        bottom: 150, // Position above info overlay
        left: 16,
        right: 80,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _currentCaption,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  offset: const Offset(1, 1),
                  blurRadius: 2,
                  color: Theme.of(context).colorScheme.scrim,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildProgressBar(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 12,
      child: Obx(() {
        // Only show progress bar when:
        // 1. Video is paused by user (not playing)
        // 2. Controller is initialized (has valid duration/position)
        // 3. This video is the active one (not being scrolled away)
        final isInitialized = _controller?.value.isInitialized ?? false;
        if (_isPlaying.value || !isInitialized || !widget.isActive) {
          return const SizedBox.shrink();
        }

        final duration = _durationMs.value;
        final position = _positionMs.value;
        final buffered = _controller?.value.buffered;

        // Calculate buffered percentage for the progress bar
        double bufferedValue = 0.0;
        if (buffered != null && buffered.isNotEmpty && duration > 0) {
          final end = buffered.last.end.inMilliseconds.toDouble();
          bufferedValue = (end / duration).clamp(0.0, 1.0);
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 32,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: bufferedValue,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.7),
                              Colors.white.withValues(alpha: 0.5),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.transparent,
                        thumbColor: Colors.white,
                        overlayColor: Colors.white.withValues(alpha: 0.3),
                        trackShape: const RoundedRectSliderTrackShape(),
                      ),
                      child: Slider(
                        value: position.clamp(0.0, duration),
                        max: duration,
                        min: 0,
                        onChanged: duration <= 0
                            ? null
                            : (value) {
                                _positionMs.value = value;
                              },
                        onChangeEnd: duration <= 0 ? null : _seekTo,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(Duration(milliseconds: position.round())),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.black.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatDuration(Duration(milliseconds: duration.round())),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.black.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _handleRetryFromError(VideoFeedController? controller) async {
    if (controller == null) return;

    controller.videoUrlSigningErrors.remove(widget.video.id);
    _signedUrlRetryRequested = false;
    _retryAttempt = 0;
    _initializationFailed = false;

    try {
      final refreshed = await controller.refreshSignedUrlIfNeeded(
        widget.video.id,
        force: true,
      );

      if (refreshed != null) {
        setState(() {});
        _initializeController();
      }
    } catch (e) {
      Get.log('Retry failed for ${widget.video.id}: $e', isError: true);
      controller.videoUrlSigningErrors[widget.video.id] = _userFriendlyMessageFromError(e);
      setState(() {});
    }
  }

  String _userFriendlyMessageFromError(Object error) {
    final msg = error.toString().toLowerCase();
    final stackTrace = error is Error ? error.stackTrace?.toString().toLowerCase() ?? '' : '';
    final fullError = '$msg $stackTrace';
    
    // Check for HTTP status codes in error message or stack trace
    if (fullError.contains('403') || msg.contains('permission') || msg.contains('unauthorized') || msg.contains('forbidden')) {
      return 'Access denied - video may be restricted';
    }
    if (fullError.contains('404') || msg.contains('not found') || msg.contains('notfound')) {
      return 'Video unavailable - it may have been removed';
    }
    if (msg.contains('timeout') || msg.contains('network') || msg.contains('socket') || msg.contains('connection')) {
      return 'Network issue - check your connection';
    }
    // Check for ExoPlayer-specific errors
    if (fullError.contains('invalidresponsecode') || fullError.contains('httpdatasource')) {
      if (fullError.contains('403')) {
        return 'Access denied - video may be restricted';
      }
      if (fullError.contains('404')) {
        return 'Video unavailable - it may have been removed';
      }
    }
    return 'Temporary error - tap to retry';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  VideoFeedController? _feedControllerOptional() {
    try {
      if (Get.isRegistered<FollowersFeedController>()) {
        return Get.find<FollowersFeedController>();
      }
      if (Get.isRegistered<VideoFeedController>()) {
        return Get.find<VideoFeedController>();
      }
    } catch (_) {
      // Ignore and return null when controller isn't available in this context.
    }
    return null;
  }
}
