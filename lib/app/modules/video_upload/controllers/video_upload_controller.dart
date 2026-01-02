import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:camera/camera.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;

import '../../../core/services/auth_service.dart';
import '../../../data/repositories/video_repository.dart';
import '../../../routes/app_routes.dart';
import '../../home/controllers/home_controller.dart';

enum VideoPrivacy { public, friends, private }

enum CameraFilter {
  none('None'),
  warm('Warm'),
  cool('Cool'),
  vintage('Vintage'),
  blackAndWhite('B&W'),
  sepia('Sepia'),
  vivid('Vivid'),
  dramatic('Dramatic');

  const CameraFilter(this.label);
  final String label;
}

class VideoUploadController extends GetxController with WidgetsBindingObserver {
  VideoUploadController({
    CameraController? cameraController,
    ImagePicker? imagePicker,
    FirebaseStorage? storage,
    AuthService? authService,
    VideoRepository? videoRepository,
    Uuid? uuid,
  })  : _cameraController = cameraController,
        _imagePicker = imagePicker ?? ImagePicker(),
        _storage = storage ?? FirebaseStorage.instance,
        _authService = authService ?? Get.find<AuthService>(),
        _videoRepository = videoRepository ?? Get.find<VideoRepository>(),
        _uuid = uuid ?? const Uuid();

  final cameras = <CameraDescription>[].obs;
  final currentCameraIndex = 0.obs;
  final isCameraInitialized = false.obs;

  CameraController? _cameraController;
  CameraController? get cameraController => _cameraController;

  final selectedVideo = Rx<XFile?>(null);
  final uploadProgress = 0.0.obs;
  final isRecording = false.obs;
  final isUploading = false.obs;
  final recordingDuration = Duration.zero.obs;
  final videoDuration = Duration.zero.obs;
  final selectedVideoSizeBytes = 0.obs;
  
  // Prevent rapid double-taps/race conditions when starting/stopping
  final isTogglingRecording = false.obs;

  final title = ''.obs;
  final description = ''.obs;
  final hashtags = <String>[].obs;

  final selectedPrivacy = VideoPrivacy.public.obs;

  final thumbnails = <String>[].obs;
  final selectedThumbnailPath = RxnString();
  final selectedThumbnailTimeMs = 0.obs;
  final isGeneratingThumbnails = false.obs;
  final isCancellingUpload = false.obs;

  // Camera enhancement controls (simplified)
  final flashMode = FlashMode.off.obs;
  final zoomLevel = 1.0.obs;
  final minZoomLevel = 1.0.obs;
  final maxZoomLevel = 1.0.obs;
  final isCountingDown = false.obs;
  final countdownRemaining = 0.obs;
  
  // Filter controls
  final selectedFilter = CameraFilter.none.obs;
  
  // Camera switching state
  final isSwitchingCamera = false.obs;
  
  // Phase 8: Draft state
  final isDraft = false.obs;
  final draftId = RxnString();

  Timer? _recordingTimer;
  Timer? _countdownTimer;
  UploadTask? _currentUploadTask;
  StreamSubscription<TaskSnapshot>? _uploadSubscription;
  String? _lastFailedUploadPath;
  String? _lastUploadedVideoId;
  StreamSubscription<Map<String, dynamic>?>? _processingSub;
  int _cameraInitGeneration = 0;
  Future<void>? _cameraDisposeFuture;

  final ImagePicker _imagePicker;
  final FirebaseStorage _storage;
  final AuthService _authService;
  final VideoRepository _videoRepository;
  final Uuid _uuid;
  final Map<String, int> _thumbnailTimeLookup = {};
  
  // Phase 8: Storage for drafts (using different name to avoid collision with FirebaseStorage)
  final GetStorage _draftStorage = GetStorage();

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _loadAvailableCameras();
  }

  @override
  void onClose() {
    // Invalidate any in-flight camera initialization to prevent using a disposed controller.
    _cameraInitGeneration++;

    // Phase 8: Auto-save draft if video exists but not uploaded
    if (selectedVideo.value != null && !isUploading.value) {
      saveDraft();
    }
    
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _processingSub?.cancel();
    _processingSub = null;
    final ctrl = _cameraController;
    if (ctrl != null) {
      _cameraDisposeFuture = ctrl.dispose();
      unawaited(_cameraDisposeFuture!);
    }
    _cameraController = null;
    WidgetsBinding.instance.removeObserver(this);
    _disposeCachedMedia();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (state == AppLifecycleState.inactive) {
      // Invalidate any in-flight camera initialization to avoid using a disposed controller.
      _cameraInitGeneration++;
      if (controller == null) {
        return;
      }

      // If the app is going inactive (e.g., opening the gallery picker),
      // silently stop any ongoing recording and reset UI state so we never
      // get stuck in a "recording" state without a visible stop button.
      unawaited(_stopRecordingQuietly());

      // Hard reset client-side recording state regardless of camera outcome
      _recordingTimer?.cancel();
      _recordingTimer = null;
      cancelCountdown();
      recordingDuration.value = Duration.zero;
      isRecording.value = false;

      _cameraDisposeFuture = controller.dispose();
      unawaited(_cameraDisposeFuture!);
      _cameraController = null;
      isCameraInitialized.value = false;
    } else if (state == AppLifecycleState.resumed) {
      if (controller == null) {
        // Continue: we still want to attempt to reinitialize if cameras exist.
      }
      // When returning from the picker (or any inactive state), ensure the UI
      // is not left believing that recording continues. This guarantees the
      // record button is available as soon as the camera comes back.
      _recordingTimer?.cancel();
      _recordingTimer = null;
      cancelCountdown();
      recordingDuration.value = Duration.zero;
      isRecording.value = false;

      if (cameras.isEmpty) return;
      
      // Reinitialize camera with timeout protection
      _reinitializeCameraWithTimeout();
    }
  }

  /// Emergency, best-effort stop that resets UI even if the camera is busy
  /// or we lost the controller mid-transition (e.g., after opening gallery).
  Future<void> emergencyStopRecording() async {
    if (isTogglingRecording.value) return;
    isTogglingRecording.value = true;
    try {
      final ctrl = _cameraController;
      if (ctrl != null && ctrl.value.isInitialized && ctrl.value.isRecordingVideo) {
        try {
          final file = await ctrl.stopVideoRecording();
          // Discard the interrupted file silently
          try { await File(file.path).delete(); } catch (_) {}
        } catch (_) {
          // Ignore – we're going to reset UI state regardless
        }
      }
    } finally {
      // Hard UI reset
      _recordingTimer?.cancel();
      _recordingTimer = null;
      cancelCountdown();
      recordingDuration.value = Duration.zero;
      isRecording.value = false;
      isTogglingRecording.value = false;
    }
  }

  Future<void> _loadAvailableCameras() async {
    try {
      final detectedCameras = await availableCameras();
      developer.log('📸 [Camera Debug] Detected ${detectedCameras.length} cameras:', name: 'VideoUpload');
      for (var i = 0; i < detectedCameras.length; i++) {
        developer.log('   Camera $i: ${detectedCameras[i].name} (${detectedCameras[i].lensDirection})', name: 'VideoUpload');
      }
      cameras.assignAll(detectedCameras);
      if (detectedCameras.isNotEmpty) {
        await _initializeCamera(detectedCameras[currentCameraIndex.value]);
      }
    } on CameraException catch (error) {
      developer.log('❌ [Camera Debug] Error loading cameras: $error', name: 'VideoUpload');
      _handleCameraError(error);
    }
  }

  Future<void> _initializeCamera(CameraDescription description) async {
    final generation = ++_cameraInitGeneration;
    try {
      // Temporarily mark as not initialized to show loading state
      isCameraInitialized.value = false;

      final pendingDispose = _cameraDisposeFuture;
      if (pendingDispose != null) {
        try {
          await pendingDispose;
        } catch (_) {
          // Best-effort: proceed even if dispose failed.
        } finally {
          if (pendingDispose == _cameraDisposeFuture) {
            _cameraDisposeFuture = null;
          }
        }
      }

      final previous = _cameraController;
      if (previous != null) {
        try {
          await previous.dispose();
        } catch (_) {
          // Best-effort; proceed with re-init.
        }
      }

      if (generation != _cameraInitGeneration) {
        return;
      }

      Future<CameraController> initWithPreset(ResolutionPreset preset) async {
        final controller = CameraController(
          description,
          preset,
          enableAudio: true,
        );
        _cameraController = controller;
        await controller.initialize();
        return controller;
      }

      CameraController controller;
      try {
        controller = await initWithPreset(ResolutionPreset.high);
      } on CameraException catch (error) {
        // Some devices/emulators can't bind the default CameraX use cases at high presets.
        // Fall back to a lower preset for a more compatible configuration.
        final details = '${error.code} ${error.description ?? ''}'.toLowerCase();
        final shouldFallback =
            details.contains('no supported surface combination') ||
            details.contains('illegalargumentexception') ||
            details.contains('unsupported surface combination');

        if (!shouldFallback) rethrow;

        final failed = _cameraController;
        if (failed != null) {
          try {
            await failed.dispose();
          } catch (_) {}
          if (_cameraController == failed) {
            _cameraController = null;
          }
        }

        controller = await initWithPreset(ResolutionPreset.medium);
      }

      if (generation != _cameraInitGeneration || _cameraController != controller) {
        try {
          await controller.dispose();
        } catch (_) {}
        return;
      }

      // Get zoom limits
      try {
        minZoomLevel.value = await controller.getMinZoomLevel();
        maxZoomLevel.value = await controller.getMaxZoomLevel();
      } catch (_) {
        // Some devices may not support zoom queries.
      }

      // Reset zoom to 1.0 when switching cameras
      zoomLevel.value = 1.0;
      try {
        await controller.setZoomLevel(1.0);
      } catch (_) {}

      if (generation != _cameraInitGeneration || _cameraController != controller) {
        try {
          await controller.dispose();
        } catch (_) {}
        return;
      }

      // Apply current flash mode
      try {
        await controller.setFlashMode(flashMode.value);
      } catch (_) {
        // Not all devices support all flash modes.
      }

      // Set auto focus mode by default
      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {
        // Some devices may not support focus mode
      }

      isCameraInitialized.value = true;
    } on CameraException catch (error) {
      isCameraInitialized.value = false;
      _handleCameraError(error);
    } catch (error) {
      // Defensive: the camera plugin can throw non-CameraException errors (e.g. controller disposed mid-init).
      isCameraInitialized.value = false;
      developer.log('Camera init failed: $error', name: 'VideoUpload');
    }
  }

  /// Reinitialize camera with timeout protection to prevent indefinite loading state
  Future<void> _reinitializeCameraWithTimeout() async {
    debugPrint('🔄 Starting camera reinitialization with timeout protection...');
    
    // First attempt with 5-second timeout
    try {
      await _initializeCamera(cameras[currentCameraIndex.value])
          .timeout(const Duration(seconds: 5));
      debugPrint('✅ Camera reinitialized successfully on first attempt');
      return;
    } on TimeoutException catch (_) {
      debugPrint('⚠️ First camera initialization attempt timed out, trying again...');
      // Clean up failed controller
      _cameraInitGeneration++;
      _cameraController?.dispose();
      _cameraController = null;
      isCameraInitialized.value = false;
    } catch (error) {
      debugPrint('❌ Error during first camera initialization: $error');
    }
    
    // Second attempt with 10-second timeout
    try {
      await _initializeCamera(cameras[currentCameraIndex.value])
          .timeout(const Duration(seconds: 10));
      debugPrint('✅ Camera reinitialized successfully on second attempt');
      return;
    } on TimeoutException catch (_) {
      debugPrint('❌ Second camera initialization attempt timed out');
      isCameraInitialized.value = false;
      Get.snackbar(
        'Camera Error',
        'Camera initialization is taking too long. Please close and reopen the camera.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
    } catch (error) {
      debugPrint('❌ Error during second camera initialization: $error');
      isCameraInitialized.value = false;
      Get.snackbar(
        'Camera Error',
        'Failed to reinitialize camera. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
    }
  }

  Future<void> switchCamera() async {
    developer.log('🔄 [Camera Debug] switchCamera() called', name: 'VideoUpload');
    developer.log('   isRecording: ${isRecording.value}', name: 'VideoUpload');
    developer.log('   cameras.length: ${cameras.length}', name: 'VideoUpload');
    developer.log('   isSwitchingCamera: ${isSwitchingCamera.value}', name: 'VideoUpload');
    developer.log('   currentCameraIndex: ${currentCameraIndex.value}', name: 'VideoUpload');
    
    // Prevent switching during recording
    if (isRecording.value) {
      developer.log('⚠️ [Camera Debug] Cannot switch - recording in progress', name: 'VideoUpload');
      Get.snackbar(
        'Cannot Switch Camera',
        'Please stop recording before switching cameras.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.withValues(alpha: 0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    
    // Provide feedback if only one camera available
    if (cameras.length <= 1) {
      developer.log('⚠️ [Camera Debug] Cannot switch - only ${cameras.length} camera(s) available', name: 'VideoUpload');
      Get.snackbar(
        'Single Camera',
        'Only one camera available on this device.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.blue.withValues(alpha: 0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    
    if (isSwitchingCamera.value) {
      developer.log('⚠️ [Camera Debug] Cannot switch - already switching', name: 'VideoUpload');
      return; // Prevent multiple simultaneous switches
    }
    
    try {
      developer.log('✅ [Camera Debug] Starting camera switch...', name: 'VideoUpload');
      isSwitchingCamera.value = true;
      final nextIndex = (currentCameraIndex.value + 1) % cameras.length;
      developer.log('   Switching from camera $currentCameraIndex to camera $nextIndex', name: 'VideoUpload');
      currentCameraIndex.value = nextIndex;
      await _initializeCamera(cameras[nextIndex]);
      developer.log('✅ [Camera Debug] Camera switch successful', name: 'VideoUpload');
    } catch (error) {
      developer.log('❌ [Camera Debug] Camera switch failed: $error', name: 'VideoUpload');
      Get.snackbar(
        'Camera Error',
        'Failed to switch camera. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        colorText: Colors.white,
      );
    } finally {
      isSwitchingCamera.value = false;
    }
  }

  // Camera Enhancement Methods

  /// Cycle through flash modes: off → on → auto → off
  Future<void> cycleFlashMode() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    FlashMode nextMode;
    switch (flashMode.value) {
      case FlashMode.off:
        nextMode = FlashMode.torch;
        break;
      case FlashMode.torch:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.auto:
      case FlashMode.always:
        nextMode = FlashMode.off;
        break;
    }

    try {
      await controller.setFlashMode(nextMode);
      flashMode.value = nextMode;
    } on CameraException catch (error) {
      Get.snackbar('Flash error', 'Unable to change flash mode: ${error.description}');
    }
  }

  /// Start recording (with optional countdown)
  Future<void> startRecordingWithTimer() async {
    // No timer needed for TikTok-style interface - start recording immediately
    await startRecording();
  }

  /// Unified toggle to start/stop recording with a simple guard to avoid races
  Future<void> toggleRecording() async {
    if (isTogglingRecording.value) return;
    
    // If camera isn't ready, try to reinitialize it first
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      debugPrint('⚠️ Camera not initialized, attempting to reinitialize...');
      Get.snackbar(
        'Initializing Camera',
        'Please wait while we prepare the camera...',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      await _reinitializeCameraWithTimeout();
      // Check again after reinitialization
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        debugPrint('❌ Camera still not ready after reinitialization');
        return;
      }
    }
    
    isTogglingRecording.value = true;
    try {
      if (isRecording.value) {
        await stopRecording();
      } else {
        await startRecordingWithTimer();
      }
    } finally {
      isTogglingRecording.value = false;
    }
  }

  /// Cancel countdown timer
  void cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    isCountingDown.value = false;
    countdownRemaining.value = 0;
  }

  /// Set zoom level (1.0 to maxZoomLevel)
  Future<void> setZoom(double level) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    // Clamp zoom level to min/max range
    final clampedZoom = level.clamp(minZoomLevel.value, maxZoomLevel.value);
    
    try {
      await controller.setZoomLevel(clampedZoom);
      zoomLevel.value = clampedZoom;
    } on CameraException catch (error) {
      // Silently fail zoom changes to avoid interrupting user experience
      if (Get.isSnackbarOpen == false) {
        Get.snackbar('Zoom error', 'Unable to adjust zoom: ${error.description}');
      }
    }
  }

  /// Handle pinch-to-zoom gesture
  void handlePinchZoom(double scale) {
    final newZoom = (zoomLevel.value * scale).clamp(minZoomLevel.value, maxZoomLevel.value);
    setZoom(newZoom);
  }
  
  /// Select a camera filter
  void selectFilter(CameraFilter filter) {
    selectedFilter.value = filter;
  }
  
  /// Get ColorFilter for the selected filter
  ColorFilter? getColorFilter() {
    switch (selectedFilter.value) {
      case CameraFilter.none:
        return null;
      case CameraFilter.warm:
        return const ColorFilter.matrix([
          1.2, 0, 0, 0, 0,
          0, 1.0, 0, 0, 0,
          0, 0, 0.8, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case CameraFilter.cool:
        return const ColorFilter.matrix([
          0.8, 0, 0, 0, 0,
          0, 0.9, 0, 0, 0,
          0, 0, 1.2, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case CameraFilter.vintage:
        return const ColorFilter.matrix([
          0.9, 0.1, 0.1, 0, 0,
          0.1, 0.8, 0.1, 0, 0,
          0.1, 0.1, 0.7, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case CameraFilter.blackAndWhite:
        return const ColorFilter.matrix([
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case CameraFilter.sepia:
        return const ColorFilter.matrix([
          0.393, 0.769, 0.189, 0, 0,
          0.349, 0.686, 0.168, 0, 0,
          0.272, 0.534, 0.131, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case CameraFilter.vivid:
        return const ColorFilter.matrix([
          1.3, 0, 0, 0, 0,
          0, 1.3, 0, 0, 0,
          0, 0, 1.3, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case CameraFilter.dramatic:
        return const ColorFilter.matrix([
          1.5, 0, 0, 0, -20,
          0, 1.5, 0, 0, -20,
          0, 0, 1.5, 0, -20,
          0, 0, 0, 1, 0,
        ]);
    }
  }

  /// Static helper to convert filter name string to ColorFilter
  /// Used by VideoPlayerWidget to apply filters during playback
  static ColorFilter? getColorFilterFromName(String? filterName) {
    if (filterName == null || filterName.isEmpty) return null;
    
    // Normalize to lowercase for comparison
    final normalized = filterName.toLowerCase();
    
    switch (normalized) {
      case 'camerafilter.none':
      case 'none':
        return null;
      case 'camerafilter.warm':
      case 'warm':
        return const ColorFilter.matrix([
          1.2, 0, 0, 0, 0,
          0, 1.0, 0, 0, 0,
          0, 0, 0.8, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 'camerafilter.cool':
      case 'cool':
        return const ColorFilter.matrix([
          0.8, 0, 0, 0, 0,
          0, 0.9, 0, 0, 0,
          0, 0, 1.2, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 'camerafilter.vintage':
      case 'vintage':
        return const ColorFilter.matrix([
          0.9, 0.1, 0.1, 0, 0,
          0.1, 0.8, 0.1, 0, 0,
          0.1, 0.1, 0.7, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 'camerafilter.blackandwhite':
      case 'blackandwhite':
      case 'b&w':
        return const ColorFilter.matrix([
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 'camerafilter.sepia':
      case 'sepia':
        return const ColorFilter.matrix([
          0.393, 0.769, 0.189, 0, 0,
          0.349, 0.686, 0.168, 0, 0,
          0.272, 0.534, 0.131, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 'camerafilter.vivid':
      case 'vivid':
        return const ColorFilter.matrix([
          1.3, 0, 0, 0, 0,
          0, 1.3, 0, 0, 0,
          0, 0, 1.3, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 'camerafilter.dramatic':
      case 'dramatic':
        return const ColorFilter.matrix([
          1.5, 0, 0, 0, -20,
          0, 1.5, 0, 0, -20,
          0, 0, 1.5, 0, -20,
          0, 0, 0, 1, 0,
        ]);
      default:
        return null;
    }
  }

  Future<void> startRecording() async {
    final controller = _cameraController;
    if (controller == null) {
      if (cameras.isEmpty) {
        Get.snackbar('Camera unavailable', 'No cameras detected on this device.');
        return;
      }
      await _initializeCamera(cameras[currentCameraIndex.value]);
    }

    final activeController = _cameraController;
    if (activeController == null || !activeController.value.isInitialized) {
      Get.snackbar('Camera error', 'The camera could not be initialized.');
      return;
    }

    if (activeController.value.isRecordingVideo) {
      return;
    }

    try {
      await activeController.prepareForVideoRecording();
    } catch (_) {
      // Some platforms might not support prepare- call; continue regardless.
    }

    try {
      await activeController.startVideoRecording();
      isRecording.value = true;
      recordingDuration.value = Duration.zero;
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        recordingDuration.value += const Duration(seconds: 1);
      });
    } on CameraException catch (error) {
      _handleCameraError(error);
      isRecording.value = false;
      _recordingTimer?.cancel();
    }
  }

  Future<void> stopRecording() async {
    final controller = _cameraController;
    // If controller is missing or not initialized, force-reset UI state
    if (controller == null || !controller.value.isInitialized) {
      isRecording.value = false;
      _recordingTimer?.cancel();
      _recordingTimer = null;
      recordingDuration.value = Duration.zero;
      return;
    }

    // If controller thinks it's not recording but UI does, force a safe reset
    if (!controller.value.isRecordingVideo) {
      isRecording.value = false;
      _recordingTimer?.cancel();
      _recordingTimer = null;
      recordingDuration.value = Duration.zero;
      // Try to prepare for a fresh recording to recover quickly
      try {
        await controller.prepareForVideoRecording();
      } catch (_) {
        // ignore
      }
      return;
    }

    try {
      final recorded = await controller.stopVideoRecording();
      final success = await _processNewSelection(recorded, validateDuration: true);
      if (success) {
        _navigateToPreview();
      }
    } on CameraException catch (error) {
      _handleCameraError(error);
    } finally {
      isRecording.value = false;
      _recordingTimer?.cancel();
      _recordingTimer = null;
      recordingDuration.value = Duration.zero;
    }
  }
  
  /// Stop recording without processing or navigating (for interruptions like gallery)
  Future<void> _stopRecordingQuietly() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isRecordingVideo) {
      return;
    }

    try {
      final recordedFile = await controller.stopVideoRecording();
      // Delete the interrupted recording file immediately
      try {
        await File(recordedFile.path).delete();
        debugPrint('🗑️ Deleted interrupted recording: ${recordedFile.path}');
      } catch (e) {
        debugPrint('⚠️ Failed to delete interrupted recording: $e');
      }
    } on CameraException catch (error) {
      debugPrint('⚠️ Error stopping recording quietly: ${error.description}');
    } finally {
      isRecording.value = false;
      recordingDuration.value = Duration.zero;
      _recordingTimer?.cancel();
      _recordingTimer = null;
      
      // Re-prepare camera for next recording
      try {
        if (controller.value.isInitialized) {
          await controller.prepareForVideoRecording();
          debugPrint('✓ Camera prepared for next recording');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to prepare camera after quiet stop: $e');
      }
    }
  }

  /// Handle close button tap - shows confirmation if recording is active
  Future<void> handleCloseTap() async {
    // If not recording, just exit
    if (!isRecording.value) {
      _exitCameraScreen();
      return;
    }

    // If recording, show confirmation dialog
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Stop Recording?'),
        content: const Text(
          'Are you sure you want to stop recording and discard this video?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Stop & Discard'),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    // If user confirmed, stop recording and exit
    if (confirmed == true) {
      await _stopRecordingQuietly();
      _exitCameraScreen();
    }
  }

  /// Exit camera screen - handles both tab and route contexts
  void _exitCameraScreen() {
    // Check if we can navigate back (full-screen route context)
    if (Get.currentRoute == Routes.videoUpload) {
      Get.back();
    } else {
      // We're in tab context (HomeView with Upload tab selected)
      // Switch back to Feed tab (index 0)
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().onTabSelected(0);
      } else {
        // Fallback: navigate to home with Feed tab selected
        Get.offAllNamed(Routes.home, arguments: {'selectTab': 'feed'});
      }
    }
  }

  Future<void> pickVideoFromGallery() async {
    try {
      // Stop any active recording before opening gallery (without navigation)
      if (isRecording.value) {
        debugPrint('⚠️ Stopping active recording before opening gallery');
        await _stopRecordingQuietly();
        // Give a moment for recording to stop cleanly
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      debugPrint('📂 Opening gallery picker...');
      final picked = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 1),
      );
      
      if (picked == null) {
        debugPrint('⚠️ No video selected from gallery');
        return;
      }
      
      debugPrint('✓ Video picked from gallery: ${picked.path}');
      
      // Show processing indicator
      Get.snackbar(
        'Processing',
        'Loading your video...',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      final success = await _processNewSelection(picked, validateDuration: true);
      if (success) {
        debugPrint('✓ Video processed successfully, navigating to preview');
        _navigateToPreview();
      } else {
        debugPrint('❌ Video processing failed');
      }
    } on PlatformException catch (error) {
      debugPrint('❌ Platform error: ${error.message}');
      Get.snackbar(
        'Gallery Error',
        error.message ?? 'Unable to access gallery. Please check app permissions.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        colorText: Colors.white,
      );
    } catch (error) {
      debugPrint('❌ Unexpected error: $error');
      Get.snackbar(
        'Error',
        'Failed to pick video. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        colorText: Colors.white,
      );
    }
  }

  Future<void> pickVideo() => pickVideoFromGallery();

  void openPreview() {
    if (selectedVideo.value == null) {
      Get.snackbar('No video', 'Record or select a video to preview.');
      return;
    }
    _navigateToPreview();
  }

  Future<void> uploadVideo() async {
    // Prevent double uploads
    if (isUploading.value) {
      debugPrint('⚠️ Upload already in progress, ignoring duplicate call');
      Get.log('Upload already in progress, ignoring duplicate call');
      return;
    }
    
    debugPrint('🎬🎬🎬 VIDEO UPLOAD FUNCTION CALLED 🎬🎬🎬');
    Get.log('=== VIDEO UPLOAD START ===');
    debugPrint('=== VIDEO UPLOAD START ===');
    
    // Set uploading state immediately to prevent double calls
    isUploading.value = true;
    isCancellingUpload.value = false;
    uploadProgress.value = 0;
    
    final videoFile = selectedVideo.value;
    if (videoFile == null) {
      debugPrint('❌ ERROR: No video selected');
      Get.log('ERROR: No video selected', isError: true);
      Get.snackbar('No video', 'Record or select a video to upload.');
      return;
    }
    debugPrint('✓ Video file path: ${videoFile.path}');
    Get.log('Video file path: ${videoFile.path}');

    final user = _authService.currentUser.value;
    if (user == null) {
      debugPrint('❌ ERROR: User not authenticated');
      Get.log('ERROR: User not authenticated', isError: true);
      Get.snackbar('Sign in required', 'Log in to upload content.');
      return;
    }
    debugPrint('✓ User ID: ${user.uid}');
    debugPrint('✓ User email: ${user.email}');
    Get.log('User ID: ${user.uid}');
    Get.log('User email: ${user.email}');

    debugPrint('🔍 About to check title...');
    final trimmedTitle = title.value.trim();
    debugPrint('🔍 Title value: "$trimmedTitle"');
    if (trimmedTitle.isEmpty) {
      Get.log('ERROR: Title is empty', isError: true);
      Get.snackbar('Add a title', 'Give your video a catchy title.');
      return;
    }
    debugPrint('✅ Title validation passed, continuing...');
    Get.log('Video title: "$trimmedTitle"');

    debugPrint('🔍 About to check duration...');
    final durationSeconds = videoDuration.value.inSeconds;
    debugPrint('🔍 Duration value: $durationSeconds');
    if (durationSeconds <= 0) {
      Get.log('ERROR: Invalid video duration: $durationSeconds', isError: true);
      Get.snackbar('Invalid video', 'We could not determine the video duration.');
      return;
    }
    Get.log('Video duration: ${durationSeconds}s');

    debugPrint('🎯 Duration check passed, generating video ID...');
    final videoId = _uuid.v4();
    debugPrint('🎯 Video ID generated: $videoId');
    
    final rawVideoPath = 'raw-videos/${user.uid}/$videoId.mp4';
    debugPrint('🎯 Storage path: $rawVideoPath');
    
    final file = File(videoFile.path);
    debugPrint('🎯 File object created');
    
    Get.log('Generated video ID: $videoId');
    Get.log('Storage path: $rawVideoPath');
    Get.log('File size: ${selectedVideoSizeBytes.value} bytes');

    // Map privacy to Firestore-accepted values (needed before upload metadata)
    final privacyValue = selectedPrivacy.value == VideoPrivacy.friends
        ? 'followers-only'
        : selectedPrivacy.value.name;

    try {
      debugPrint('📤📤📤 ABOUT TO START FIREBASE STORAGE UPLOAD 📤📤📤');
      Get.log('Starting upload to Firebase Storage...');

      debugPrint('🔥 Step 1: Creating storage reference...');
      final storageRef = _storage.ref(rawVideoPath);
      debugPrint('🔥 Step 2: Storage reference created: ${storageRef.fullPath}');
      
      debugPrint('🔥 Step 3: Creating putFile task...');
      final uploadTask = storageRef.putFile(
            file,
            SettableMetadata(
              contentType: 'video/mp4',
              // Pass privacy so the Cloud Function can honor access mode even if the Firestore document isn't written yet
              customMetadata: {
                'privacy': privacyValue,
              },
            ),
          );
      debugPrint('🔥 Step 4: Upload task created successfully');
      debugPrint('🔥 Step 4: Upload task created successfully');
      _currentUploadTask = uploadTask;
      Get.log('Upload task created');

      debugPrint('🔥 Step 5: Setting up upload progress listener...');
      _uploadSubscription = uploadTask.snapshotEvents.listen(
        (snapshot) {
          if (snapshot.totalBytes > 0) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            uploadProgress.value = progress;
            Get.log('Upload progress: ${(progress * 100).toStringAsFixed(1)}% (${snapshot.bytesTransferred}/${snapshot.totalBytes} bytes)');
          }
        },
        onError: (error) {
          debugPrint('❌ UPLOAD STREAM ERROR: $error');
          Get.log('ERROR: Upload stream error: $error', isError: true);
          uploadProgress.value = 0;
          _lastFailedUploadPath = rawVideoPath;
        },
      );
      debugPrint('🔥 Step 6: Progress listener set up');

      debugPrint('🔥 Step 7: Awaiting upload completion...');
      Get.log('Waiting for upload to complete...');
      final TaskSnapshot snapshot = await uploadTask;
      debugPrint('🔥 Step 8: Upload completed! State: ${snapshot.state}');
      Get.log('Upload completed! State: ${snapshot.state}');
      
      debugPrint('🔥 Step 9: Cancelling upload subscription...');
      await _uploadSubscription?.cancel();
      _uploadSubscription = null;
      _currentUploadTask = null;
      debugPrint('🔥 Step 10: Subscription cancelled');

      debugPrint('🔥 Step 11: Checking if upload was cancelled...');
      if (isCancellingUpload.value) {
        debugPrint('⚠️ Upload was cancelled by user');
        Get.log('Upload was cancelled by user');
        await _cleanupAfterCancellation(snapshot.ref);
        return;
      }
      debugPrint('🔥 Step 12: Upload not cancelled, proceeding...');

      debugPrint('🔥 Step 13: Getting download URL from Storage...');
      Get.log('Getting download URL...');

      // Retry briefly to avoid rare object-not-found immediately after upload.
      final rawVideoUrl = await _getDownloadUrlWithRetry(snapshot.ref);
      debugPrint('🔥 Step 14: Download URL obtained: $rawVideoUrl');
      Get.log('Download URL obtained: $rawVideoUrl');

      Get.log('Privacy setting: $privacyValue');

      // Create the Firestore draft first (without thumbnail), so Storage rules can validate ownership for thumbnail writes
  // debugPrint('🚨🚨🚨 ABOUT TO CREATE FIRESTORE DOCUMENT - THIS SHOULD NOT HAPPEN YET! 🚨🚨🚨');
      Get.log('Creating Firestore video document...');
      Get.log('Video metadata: {');
      Get.log('  videoId: $videoId,');
      Get.log('  ownerId: ${user.uid},');
      Get.log('  title: "$trimmedTitle",');
      Get.log('  description: "${description.value.trim()}",');
      Get.log('  hashtags: ${hashtags.toList()},');
      Get.log('  durationSeconds: $durationSeconds,');
      Get.log('  fileSizeBytes: ${selectedVideoSizeBytes.value},');
      Get.log('  privacy: $privacyValue,');
      Get.log('  filterUsed: ${selectedFilter.value != CameraFilter.none ? selectedFilter.value.name : null}');
      Get.log('}');
      
      try {
        await _videoRepository.createVideoDraft(
          videoId: videoId,
          ownerId: user.uid,
          title: trimmedTitle,
          description: description.value.trim(),
          hashtags: hashtags.toList(),
          rawVideoUrl: rawVideoUrl,
          rawVideoStoragePath: rawVideoPath,
          durationSeconds: durationSeconds,
          fileSizeBytes: selectedVideoSizeBytes.value,
          privacy: privacyValue,
          filterUsed: selectedFilter.value != CameraFilter.none 
              ? selectedFilter.value.name 
              : null,
        );
        Get.log('✓ Firestore video document created successfully');
      } on FirebaseException catch (e) {
        Get.log('✗ FIRESTORE ERROR: ${e.code} - ${e.message}', isError: true);
        Get.log('Error details: $e', isError: true);
        Get.log('Stack trace:', isError: true);
        Get.log(StackTrace.current.toString(), isError: true);
        // Clean up uploaded video file
        try {
          Get.log('Cleaning up uploaded video file...');
          await snapshot.ref.delete();
          Get.log('✓ Cleanup successful');
        } catch (cleanupError) {
          Get.log('✗ Cleanup failed: $cleanupError', isError: true);
        }
        _showRetrySnackbar(
          'Upload failed',
          'Could not create video record: ${e.message ?? e.code}',
        );
        if (_lastUploadedVideoId != null) {
          unawaited(_videoRepository.logUploadFailed(_lastUploadedVideoId!, code: e.code));
        }
        return;
      } catch (e) {
        Get.log('✗ UNEXPECTED ERROR creating video draft: $e', isError: true);
        Get.log('Error type: ${e.runtimeType}', isError: true);
        Get.log('Stack trace:', isError: true);
        Get.log(StackTrace.current.toString(), isError: true);
        // Clean up uploaded video file
        try {
          Get.log('Cleaning up uploaded video file...');
          await snapshot.ref.delete();
          Get.log('✓ Cleanup successful');
        } catch (cleanupError) {
          Get.log('✗ Cleanup failed: $cleanupError', isError: true);
        }
        _showRetrySnackbar(
          'Upload failed',
          'Could not create video record. Please try again.',
        );
        if (_lastUploadedVideoId != null) {
          unawaited(_videoRepository.logUploadFailed(_lastUploadedVideoId!));
        }
        return;
      }

  // Start watching processing status in real-time (Step 8.9)
      _startProcessingWatcher(videoId);
      _lastUploadedVideoId = videoId;
  // Log analytics for upload started (8.14)
  unawaited(_videoRepository.logUploadStarted(videoId));

      // Optionally upload thumbnail after draft exists, then update video document
      final selectedThumb = selectedThumbnailPath.value;
      if (selectedThumb != null) {
  debugPrint('🖼️ [THUMBNAIL] Starting thumbnail upload...');
  debugPrint('🖼️ [THUMBNAIL] Thumbnail path: $selectedThumb');
        Get.log('Starting thumbnail upload for $videoId');
        
          final thumbFile = File(selectedThumb);
        if (await thumbFile.exists()) {
          final thumbPath = 'thumbnails/$videoId.jpg';
            debugPrint('🖼️ [THUMBNAIL] Storage path: $thumbPath');
            debugPrint('🖼️ [THUMBNAIL] File exists, uploading...');
          Get.log('Thumbnail file exists, uploading to $thumbPath');
          
          try {
            final thumbSnapshot = await _storage.ref(thumbPath).putFile(
                  thumbFile,
                  SettableMetadata(
                    contentType: 'image/jpeg',
                    cacheControl: 'public, max-age=604800', // 7 days
                  ),
                );
            debugPrint('✅ [THUMBNAIL] Upload completed successfully');
            Get.log('✓ Thumbnail uploaded successfully');
            
            final thumbnailUrl = await thumbSnapshot.ref.getDownloadURL();
            debugPrint('✅ [THUMBNAIL] Download URL obtained: $thumbnailUrl');
            Get.log('Thumbnail URL: $thumbnailUrl');
            
            final thumbnailStoragePath = thumbPath;
            final thumbnailTimeMs = selectedThumbnailTimeMs.value > 0
                ? selectedThumbnailTimeMs.value
                : null;

            await _videoRepository.updateVideoThumbnail(
              videoId: videoId,
              thumbnailUrl: thumbnailUrl,
              thumbnailStoragePath: thumbnailStoragePath,
              thumbnailTimeMs: thumbnailTimeMs,
            );
            debugPrint('✅ [THUMBNAIL] Firestore updated with thumbnail URL');
            Get.log('✓ Video thumbnail updated in Firestore');
          } on FirebaseException catch (thumbError) {
            debugPrint('❌ [THUMBNAIL] Firebase exception: ${thumbError.code}');
            debugPrint('❌ [THUMBNAIL] Error message: ${thumbError.message}');
            debugPrint('❌ [THUMBNAIL] Full error: $thumbError');
            Get.log('✗ Thumbnail upload failed: ${thumbError.code} - ${thumbError.message}', isError: true);
            // Don't fail the entire upload if thumbnail fails
            Get.log('Continuing without thumbnail...', isError: true);
          } catch (thumbError) {
            debugPrint('❌ [THUMBNAIL] Unexpected error: $thumbError');
            Get.log('✗ Thumbnail upload unexpected error: $thumbError', isError: true);
            // Don't fail the entire upload if thumbnail fails
          }
        } else {
          debugPrint('⚠️ [THUMBNAIL] Thumbnail file does not exist');
          Get.log('Thumbnail file does not exist, skipping');
        }
      } else {
        debugPrint('ℹ️ [THUMBNAIL] No thumbnail selected');
        Get.log('No thumbnail selected');
      }

      Get.snackbar('Upload started', 'We\'ll notify you when it\'s ready.',
          snackPosition: SnackPosition.BOTTOM);
      await _resetAfterUpload();
      // Optionally keep reference for later navigation if needed
      if (_lastUploadedVideoId != null) {
        Get.log('Upload submitted for videoId=$_lastUploadedVideoId');
      }
      Get.until((route) => route.settings.name == Routes.videoUpload || route.isFirst);
      // Upload has completed to Storage successfully
      Get.log('✓ Video upload completed successfully');
      Get.log('=== VIDEO UPLOAD END (SUCCESS) ===');
      unawaited(_videoRepository.logUploadCompleted(videoId));
    } on FirebaseException catch (error) {
      debugPrint('❌❌❌ FIREBASE EXCEPTION CAUGHT ❌❌❌');
      debugPrint('❌ Error code: ${error.code}');
      debugPrint('❌ Error message: ${error.message}');
      debugPrint('❌ Full error: $error');
      Get.log('✗ FIREBASE EXCEPTION in uploadVideo(): ${error.code}', isError: true);
      Get.log('Error message: ${error.message}', isError: true);
      Get.log('Error details: $error', isError: true);
      Get.log('Stack trace:', isError: true);
      Get.log(StackTrace.current.toString(), isError: true);
      Get.log('=== VIDEO UPLOAD END (FIREBASE ERROR) ===', isError: true);
      
      _lastFailedUploadPath = rawVideoPath;
      await _cleanupFailedUpload();
      
      // Handle rate limit errors specifically
      if (error.code == 'rate-limit-exceeded' || error.message?.contains('RATE_LIMIT_EXCEEDED') == true) {
        // Parse retry information from error message (handles both singular and plural)
        final retryMatch = RegExp(r'(\d+)\s+(minutes?|seconds?)').firstMatch(error.message ?? '');
        final retryTime = retryMatch?.group(1) ?? '0';
        final retryUnit = retryMatch?.group(2) ?? 'minutes';
        
        Get.snackbar(
          'Upload Limit Reached',
          'You can upload again in $retryTime $retryUnit',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.shade700,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
          icon: const Icon(Icons.timer, color: Colors.white),
        );
      } else {
        _showRetrySnackbar(
          'Upload failed',
          error.message ?? 'Could not upload video. Check your connection.',
        );
      }
      
      if (_lastUploadedVideoId != null) {
        unawaited(_videoRepository.logUploadFailed(_lastUploadedVideoId!, code: error.code));
      }
    } catch (error, stackTrace) {
      debugPrint('❌❌❌ UNEXPECTED ERROR CAUGHT ❌❌❌');
      debugPrint('❌ Error type: ${error.runtimeType}');
      debugPrint('❌ Error message: $error');
      debugPrint('❌ Stack trace: $stackTrace');
      Get.log('✗ UNEXPECTED ERROR in uploadVideo(): $error', isError: true);
      Get.log('Error type: ${error.runtimeType}', isError: true);
      Get.log('Stack trace:', isError: true);
      Get.log(stackTrace.toString(), isError: true);
      Get.log('=== VIDEO UPLOAD END (UNEXPECTED ERROR) ===', isError: true);
      
      _lastFailedUploadPath = rawVideoPath;
      await _cleanupFailedUpload();
      _showRetrySnackbar('Upload failed', error.toString());
      if (_lastUploadedVideoId != null) {
        unawaited(_videoRepository.logUploadFailed(_lastUploadedVideoId!));
      }
    } finally {
      Get.log('Upload cleanup: resetting upload state');
      isUploading.value = false;
      isCancellingUpload.value = false;
      uploadProgress.value = 0;
      _currentUploadTask = null;
      _uploadSubscription = null;
    }
  }

  void _startProcessingWatcher(String videoId) {
    // Cancel existing watcher if any
    _processingSub?.cancel();
    Timer? stuckTimer;
    bool readyOrFailed = false;
    String? lastStatus;
    bool processingSnackShown = false;
    void cancelStuckTimer() {
      try {
        stuckTimer?.cancel();
      } catch (_) {}
      stuckTimer = null;
    }
    _processingSub = _videoRepository.watchVideoDocument(videoId).listen(
      (data) {
        if (data == null) return;
        final status = (data['status'] as String?) ?? '';
        if (status.isEmpty) return;
        if (status == lastStatus) return;
        lastStatus = status;
        switch (status) {
          case 'processing':
            // Schedule a single "stuck" helper after a grace period.
            // This helps users recover when storage triggers fail or time out (large uploads).
            stuckTimer ??= Timer(const Duration(minutes: 2), () async {
                if (readyOrFailed) return;
                Get.snackbar(
                  'Still processing',
                  'If this takes too long, tap retry.',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 8),
                  mainButton: TextButton(
                    onPressed: () async {
                      try {
                        await _videoRepository.retryProcessing(videoId);
                        Get.snackbar(
                          'Retrying',
                          'We are retrying video processing.',
                          snackPosition: SnackPosition.BOTTOM,
                          duration: const Duration(seconds: 2),
                        );
                      } on FirebaseFunctionsException catch (e) {
                        final message = e.message ?? e.code;
                        Get.snackbar('Retry failed', message, snackPosition: SnackPosition.BOTTOM);
                      } catch (e) {
                        Get.snackbar('Retry failed', e.toString(),
                            snackPosition: SnackPosition.BOTTOM);
                      }
                    },
                    child: const Text('RETRY'),
                  ),
                );
              });
            // Show unobtrusive info once per watcher to avoid snackbar spam.
            if (!processingSnackShown) {
              processingSnackShown = true;
              Get.snackbar(
                'Processing...',
                'We\'re preparing your clip for streaming.',
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 2),
              );
            }
            break;
          case 'ready':
            readyOrFailed = true;
            cancelStuckTimer();
            final hlsUrl = data['hlsUrl'] as String?;
            if (hlsUrl != null && hlsUrl.isNotEmpty) {
              Get.snackbar(
                'Video ready',
                'Your video is ready to watch.',
                snackPosition: SnackPosition.BOTTOM,
              );
            } else {
              Get.snackbar(
                'Video ready',
                'Processing complete (no HLS URL found).',
                snackPosition: SnackPosition.BOTTOM,
              );
            }
            _processingSub?.cancel();
            _processingSub = null;
            break;
          case 'failed':
            readyOrFailed = true;
            cancelStuckTimer();
            final error = (data['error'] as String?) ?? 'Unknown error';
            Get.snackbar(
              'Processing failed',
              error,
              snackPosition: SnackPosition.BOTTOM,
              duration: const Duration(seconds: 5),
              mainButton: TextButton(
                onPressed: () async {
                  try {
                    await _videoRepository.retryProcessing(videoId);
                    Get.snackbar('Retrying', 'We are retrying video processing.',
                        snackPosition: SnackPosition.BOTTOM,
                        duration: const Duration(seconds: 2));
                  } on FirebaseFunctionsException catch (e) {
                    final message = e.message ?? e.code;
                    Get.snackbar('Retry failed', message, snackPosition: SnackPosition.BOTTOM);
                  } catch (e) {
                    Get.snackbar('Retry failed', e.toString(),
                        snackPosition: SnackPosition.BOTTOM);
                  }
                },
                child: const Text('RETRY'),
              ),
            );
            _processingSub?.cancel();
            _processingSub = null;
            break;
        }
      },
      onError: (e) {
        Get.log('Processing watcher error: $e', isError: true);
      },
    );
  }

  Future<void> cancelUpload() async {
    if (!isUploading.value || isCancellingUpload.value) {
      return;
    }

    isCancellingUpload.value = true;
    Get.snackbar(
      'Cancelling',
      'Stopping upload...',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
    );

    try {
      await _currentUploadTask?.cancel();
      await _uploadSubscription?.cancel();
    } catch (_) {
      // Ignore cancellation errors
    }

    _currentUploadTask = null;
    _uploadSubscription = null;
    await _cleanupFailedUpload();

    isUploading.value = false;
    isCancellingUpload.value = false;
    uploadProgress.value = 0;

    Get.snackbar(
      'Upload cancelled',
      'Your video was not uploaded.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> retryLastUpload() async {
    if (isUploading.value) {
      Get.snackbar(
        'Upload in progress',
        'Please wait for the current upload to finish.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (selectedVideo.value == null) {
      Get.snackbar(
        'No video',
        'Record or select a video to upload.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    await uploadVideo();
  }

  Future<void> _cleanupAfterCancellation(Reference storageRef) async {
    try {
      await storageRef.delete();
    } catch (_) {
      // Ignore cleanup errors
    }

    Get.snackbar(
      'Upload cancelled',
      'Your video was not uploaded.',
      snackPosition: SnackPosition.BOTTOM,
    );

    isUploading.value = false;
    isCancellingUpload.value = false;
    uploadProgress.value = 0;
  }

  Future<void> _cleanupFailedUpload() async {
    // Clean up any partially uploaded files
    if (_lastFailedUploadPath != null) {
      try {
        await _storage.ref(_lastFailedUploadPath!).delete();
      } catch (_) {
        // Ignore cleanup errors
      }
    }
  }

  void _showRetrySnackbar(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 5),
      mainButton: TextButton(
        onPressed: retryLastUpload,
        child: const Text('RETRY'),
      ),
    );
  }

  void addHashtagsFromInput(String value) {
    final raw = value.trim();
    if (raw.isEmpty) {
      return;
    }

    final parsed = raw
        .split(RegExp(r'[ ,#]+'))
        .where((element) => element.isNotEmpty)
        .map((tag) => '#${tag.replaceAll('#', '')}')
        .toSet()
        .toList();
    
    // Add new hashtags without clearing existing ones (avoid duplicates)
    for (final tag in parsed) {
      if (!hashtags.contains(tag) && hashtags.length < 10) {
        hashtags.add(tag);
      }
    }
  }

  void removeHashtag(String tag) {
    hashtags.remove(tag);
  }

  void selectThumbnail(String path) {
    if (!thumbnails.contains(path)) return;
    selectedThumbnailPath.value = path;
    selectedThumbnailTimeMs.value = _thumbnailTimeLookup[path] ?? 0;
  }

  void setPrivacy(VideoPrivacy value) {
    selectedPrivacy.value = value;
  }
  
  Future<bool> _processNewSelection(
    XFile file, {
    required bool validateDuration,
  }) async {
    try {
      final cached = await _cacheVideo(file);
      final metadata = await _extractMetadata(cached.path);

      if (validateDuration && !_isDurationAllowed(metadata.duration)) {
        await _deleteFileSilently(cached.path);
        Get.snackbar(
          'Unsupported length',
          'Choose a clip between 15 and 60 seconds.',
        );
        return false;
      }

      await _replaceCurrentVideo(cached, metadata);
      return true;
    } catch (error) {
      Get.snackbar('Video error', 'Unable to process the selected video.');
      return false;
    }
  }

  Future<void> _replaceCurrentVideo(XFile cached, _VideoMetadata metadata) async {
    final previous = selectedVideo.value;
    if (previous != null && previous.path != cached.path) {
      unawaited(_deleteFileSilently(previous.path));
    }

    selectedVideo.value = cached;
    selectedVideoSizeBytes.value = metadata.sizeBytes;
    recordingDuration.value = metadata.duration;
    videoDuration.value = metadata.duration;
    title.value = '';
    description.value = '';
    hashtags.clear();
    selectedPrivacy.value = VideoPrivacy.public;
    await _deleteGeneratedThumbnails();
    selectedThumbnailPath.value = null;
    selectedThumbnailTimeMs.value = 0;

    unawaited(_generateThumbnails(cached.path));
  }

  Future<XFile> _cacheVideo(XFile source) async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/snapflow_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final fileName = 'clip_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final targetPath = '${cacheDir.path}/$fileName';
    await source.saveTo(targetPath);
    if (source.path != targetPath) {
      unawaited(_deleteFileSilently(source.path));
    }

    return XFile(targetPath, name: fileName, mimeType: 'video/mp4');
  }

  Future<_VideoMetadata> _extractMetadata(String path) async {
    final file = File(path);
    final sizeBytes = await file.length();
    final player = VideoPlayerController.file(file);
    try {
      await player.initialize();
      return _VideoMetadata(duration: player.value.duration, sizeBytes: sizeBytes);
    } finally {
      await player.dispose();
    }
  }

  bool _isDurationAllowed(Duration duration) {
    const minimum = Duration(seconds: 15);
    const maximum = Duration(seconds: 60);
    return duration >= minimum && duration <= maximum;
  }

  Future<void> _generateThumbnails(String videoPath) async {
    if (videoDuration.value.inMilliseconds <= 0) {
      return;
    }

    final durationMs = videoDuration.value.inMilliseconds;
    final tempDir = await getTemporaryDirectory();
    final thumbsDir = Directory('${tempDir.path}/snapflow_thumbs');
    if (!await thumbsDir.exists()) {
      await thumbsDir.create(recursive: true);
    }

    await _deleteGeneratedThumbnails();
    selectedThumbnailPath.value = null;
    selectedThumbnailTimeMs.value = 0;

    isGeneratingThumbnails.value = true;
    try {
      const candidateCount = 4;
      final steps = candidateCount + 1;
      final generated = <String>[];
      
      // Generate unique filename base for this video
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      for (var i = 1; i <= candidateCount; i++) {
        final timeMs = (durationMs * i / steps).round().clamp(0, durationMs);
        
        // Create unique filename for each thumbnail
        final uniqueFilename = 'thumb_${timestamp}_${i}_${timeMs}ms.jpg';
        final targetPath = '${thumbsDir.path}/$uniqueFilename';
        
        developer.log('🖼️ [Thumbnail Gen] Generating thumbnail $i at ${timeMs}ms', name: 'VideoUpload');
        developer.log('🖼️ [Thumbnail Gen] Target path: $targetPath', name: 'VideoUpload');
        
        final thumbPath = await vt.VideoThumbnail.thumbnailFile(
          video: videoPath,
          thumbnailPath: targetPath,
          imageFormat: vt.ImageFormat.JPEG,
          maxHeight: 480,
          quality: 80,
          timeMs: timeMs,
        );

        developer.log('🖼️ [Thumbnail Gen] Generated path: $thumbPath', name: 'VideoUpload');
        
        if (thumbPath != null) {
          generated.add(thumbPath);
          _thumbnailTimeLookup[thumbPath] = timeMs;
        }
      }
      
      developer.log('🖼️ [Thumbnail Gen] Total generated: ${generated.length}', name: 'VideoUpload');
      developer.log('🖼️ [Thumbnail Gen] Paths: ${generated.join('\n')}', name: 'VideoUpload');

      thumbnails.assignAll(generated);
      if (generated.isNotEmpty) {
        final first = generated.first;
        selectedThumbnailPath.value = first;
        selectedThumbnailTimeMs.value = _thumbnailTimeLookup[first] ?? 0;
        developer.log('🖼️ [Thumbnail Gen] Auto-selected first: $first', name: 'VideoUpload');
      }
    } catch (error) {
      Get.snackbar('Thumbnail warning', 'Unable to generate thumbnails.');
    } finally {
      isGeneratingThumbnails.value = false;
    }
  }

  Future<void> _resetAfterUpload() async {
    final current = selectedVideo.value;
    if (current != null) {
      await _deleteFileSilently(current.path);
    }
    selectedVideo.value = null;
    selectedVideoSizeBytes.value = 0;
    recordingDuration.value = Duration.zero;
    videoDuration.value = Duration.zero;
    title.value = '';
    description.value = '';
    hashtags.clear();
    selectedPrivacy.value = VideoPrivacy.public;
    await _deleteGeneratedThumbnails();
    selectedThumbnailPath.value = null;
    selectedThumbnailTimeMs.value = 0;
  }

  Future<void> resetSelection() async {
    final current = selectedVideo.value;
    if (current != null) {
      await _deleteFileSilently(current.path);
    }
    selectedVideo.value = null;
    recordingDuration.value = Duration.zero;
    videoDuration.value = Duration.zero;
    selectedVideoSizeBytes.value = 0;
  await _deleteGeneratedThumbnails();
    selectedThumbnailPath.value = null;
    selectedThumbnailTimeMs.value = 0;
    title.value = '';
    description.value = '';
    hashtags.clear();
    selectedPrivacy.value = VideoPrivacy.public;
  }

  void _navigateToPreview() {
    if (Get.currentRoute == Routes.videoPost) {
      return;
    }
    Get.toNamed(Routes.videoPost);
  }

  Future<void> _disposeCachedMedia() async {
    final selected = selectedVideo.value;
    if (selected != null) {
      await _deleteFileSilently(selected.path);
    }
    await _deleteGeneratedThumbnails();
  }

  Future<void> _deleteFileSilently(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore delete failures.
    }
  }

  Future<void> _deleteGeneratedThumbnails() async {
    for (final thumb in List<String>.from(thumbnails)) {
      await _deleteFileSilently(thumb);
    }
    thumbnails.clear();
    _thumbnailTimeLookup.clear();
  }
  
  // Phase 8: Auto-Save Drafts Methods
  
  /// Save the current video and metadata as a draft
  Future<void> saveDraft() async {
    if (selectedVideo.value == null) return;
    
    try {
      final draft = {
        'id': draftId.value ?? _uuid.v4(),
        'videoPath': selectedVideo.value!.path,
        'title': title.value,
        'description': description.value,
        'hashtags': hashtags.toList(),
        // Store canonical privacy string so drafts reload correctly
        'privacy': _privacyToCanonical(selectedPrivacy.value),
        'thumbnailPath': selectedThumbnailPath.value,
        'selectedFilter': selectedFilter.value.toString(),
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      // Save to local storage using GetStorage
      await _draftStorage.write('video_draft_${draft['id']}', draft);
      
      isDraft.value = true;
      draftId.value = draft['id'] as String;
      
      Get.snackbar(
        'Draft Saved',
        'Your video has been saved as a draft',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (error) {
      // Silently fail - draft save is non-critical
      // In production, consider logging to Firebase Crashlytics
    }
  }
  
  /// Load a draft by ID
  Future<void> loadDraft(String id) async {
    try {
      final draft = _draftStorage.read('video_draft_$id') as Map<String, dynamic>?;
      if (draft == null) {
        Get.snackbar('Draft not found', 'Could not load the specified draft');
        return;
      }
      
      // Restore video
      final videoPath = draft['videoPath'] as String;
      if (!await File(videoPath).exists()) {
        Get.snackbar('Video not found', 'The draft video file no longer exists');
        return;
      }
      selectedVideo.value = XFile(videoPath);
      
      // Restore metadata
      title.value = draft['title'] as String? ?? '';
      description.value = draft['description'] as String? ?? '';
      hashtags.assignAll((draft['hashtags'] as List?)?.cast<String>() ?? []);
      
      // Restore privacy
      final privacyStr = draft['privacy'] as String?;
      final normalizedPrivacy = _normalizeDraftPrivacy(privacyStr);
      switch (normalizedPrivacy) {
        case 'public':
          selectedPrivacy.value = VideoPrivacy.public;
          break;
        case 'followers-only':
          selectedPrivacy.value = VideoPrivacy.friends;
          break;
        case 'private':
          selectedPrivacy.value = VideoPrivacy.private;
          break;
        default:
          // Fallback to public if unknown value
          selectedPrivacy.value = VideoPrivacy.public;
          if (privacyStr != null && privacyStr.isNotEmpty) {
            Get.log('Unknown privacy value in draft: $privacyStr, defaulting to public', isError: true);
          }
      }
      
      // Restore thumbnail
      selectedThumbnailPath.value = draft['thumbnailPath'] as String?;
      
      // Restore filter
      final filterStr = draft['selectedFilter'] as String?;
      if (filterStr != null) {
        for (final filter in CameraFilter.values) {
          if (filterStr.contains(filter.name)) {
            selectedFilter.value = filter;
            break;
          }
        }
      }
      
      isDraft.value = true;
      draftId.value = id;
      
      Get.snackbar(
        'Draft Loaded',
        'Your draft has been restored',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      Get.snackbar('Error', 'Failed to load draft: $error');
    }
  }
  
  /// Delete a draft by ID
  Future<void> deleteDraft(String id) async {
    try {
      await _draftStorage.remove('video_draft_$id');
      
      if (draftId.value == id) {
        isDraft.value = false;
        draftId.value = null;
      }
    } catch (error) {
      // Silently fail - draft deletion is non-critical
    }
  }

  /// Convert enum to canonical string used across the app and backend.
  String _privacyToCanonical(VideoPrivacy value) {
    switch (value) {
      case VideoPrivacy.public:
        return 'public';
      case VideoPrivacy.friends:
        return 'followers-only';
      case VideoPrivacy.private:
        return 'private';
    }
  }

  /// Normalize legacy draft privacy strings into canonical values.
  /// Supports old formats like 'VideoPrivacy.friends' or 'friends'.
  String? _normalizeDraftPrivacy(String? raw) {
    if (raw == null) return null;
    final lower = raw.toLowerCase();
    if (lower.contains('followers-only') || lower.contains('friends')) {
      return 'followers-only';
    }
    if (lower.contains('private')) {
      return 'private';
    }
    if (lower.contains('public')) {
      return 'public';
    }
    return null;
  }
  
  /// Get all saved drafts
  List<Map<String, dynamic>> getAllDrafts() {
    final keys = _draftStorage.getKeys();
    final drafts = <Map<String, dynamic>>[];
    
    for (final key in keys) {
      if (key.toString().startsWith('video_draft_')) {
        final draft = _draftStorage.read(key.toString()) as Map<String, dynamic>?;
        if (draft != null) {
          drafts.add(draft);
        }
      }
    }
    
    // Sort by creation date (newest first)
    drafts.sort((a, b) {
      final dateA = DateTime.parse(a['createdAt'] as String);
      final dateB = DateTime.parse(b['createdAt'] as String);
      return dateB.compareTo(dateA);
    });
    
    return drafts;
  }

  void _handleCameraError(CameraException error) {
    developer.log(
      'Camera error: ${error.code} - ${error.description ?? ''}',
      name: 'VideoUpload',
    );
    Get.snackbar(
      'Camera error',
      'The camera could not be started. Please close and reopen the camera.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }

  /// Attempts to fetch the download URL, retrying a few times if the object
  /// is not immediately available after upload.
  Future<String> _getDownloadUrlWithRetry(Reference ref) async {
    const attempts = 3;
    FirebaseException? lastError;
    for (var i = 0; i < attempts; i++) {
      try {
        return await ref.getDownloadURL();
      } on FirebaseException catch (e) {
        lastError = e;
        if (e.code != 'object-not-found') rethrow;
        // Small backoff before retrying
        await Future.delayed(Duration(milliseconds: 400 * (i + 1)));
      }
    }
    // If we exhausted retries, rethrow the last error.
    throw lastError ??
        FirebaseException(
          plugin: 'firebase_storage',
          code: 'download-url-failed',
          message: 'Failed to obtain download URL after retries.',
        );
  }
}

class _VideoMetadata {
  const _VideoMetadata({required this.duration, required this.sizeBytes});

  final Duration duration;
  final int sizeBytes;
}
