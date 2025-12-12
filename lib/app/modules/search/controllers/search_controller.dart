import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../../data/models/user_model.dart' as models show UserModel; // avoid name clash
import '../../../data/models/video_model.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/video_repository.dart';
import '../../../core/services/error_service.dart';

class SearchModuleController extends GetxController {
  final textController = TextEditingController();
  final query = ''.obs;
  final isSearching = false.obs;
  final users = <models.UserModel>[].obs;
  final UserRepository _userRepository = Get.find<UserRepository>();
  final VideoRepository _videoRepository = Get.find<VideoRepository>();
  Worker? _queryWorker; // debounce worker

  // Videos tab state
  final videos = <VideoModel>[].obs;

  // Trending state
  final trendingHashtags = <String>[].obs;
  final trendingUsers = <models.UserModel>[].obs;
  final isLoadingTrending = false.obs;

  // Search history (persisted)
  final searchHistory = <String>[].obs;
  final GetStorage _storage = GetStorage();
  static const String _historyKey = 'search_history';

  @override
  void onInit() {
    super.onInit();
    _loadSearchHistory();
    loadTrending();
    // Register a single debounce worker for the query observable
    _queryWorker = debounce<String>(
      query,
      (q) async => _runSearch(q),
      time: const Duration(milliseconds: 350),
    );
    _applyRouteArguments();
  }

  void onQueryChanged(String value) {
    query.value = value;
  }

  Future<void> _runSearch(String q) async {
    final term = q.trim();
    if (term.isEmpty) {
      users.clear();
      videos.clear();
      return;
    }
    try {
      isSearching.value = true;
      
      // Get following list for followers-only video search
      final currentUser = FirebaseAuth.instance.currentUser;
      final followingIds = currentUser != null 
          ? await _videoRepository.getFollowingUserIds(currentUser.uid)
          : <String>[];
      
      // Execute users and videos in parallel
      final results = await Future.wait([
        _userRepository.searchUsers(term, limit: 25),
        _videoRepository.searchVideos(term, limit: 30, followedUserIds: followingIds),
      ]);
      users.assignAll(results[0] as List<models.UserModel>);
      videos.assignAll(results[1] as List<VideoModel>);
      _saveSearchToHistory(term);
    } catch (e, stackTrace) {
      Get.log('Search failed for "$term": $e', isError: true);
      try {
        final errorService = Get.isRegistered<ErrorService>() ? Get.find<ErrorService>() : null;
        errorService?.handleError(e, context: 'search', stackTrace: stackTrace);
      } catch (_) {
        // fall through; we still clear results below
      }
      users.clear();
      videos.clear();
    } finally {
      isSearching.value = false;
    }
  }

  Future<void> loadTrending() async {
    try {
      isLoadingTrending.value = true;
      final results = await Future.wait([
        _videoRepository.getTrendingHashtags(limit: 10),
        _userRepository.getTrendingCreators(limit: 10),
      ]);
      trendingHashtags.assignAll(results[0] as List<String>);
      trendingUsers.assignAll(results[1] as List<models.UserModel>);
    } catch (_) {
      trendingHashtags.clear();
      trendingUsers.clear();
    } finally {
      isLoadingTrending.value = false;
    }
  }

  void searchByHashtag(String hashtag) {
    // Accept with or without '#'
    final normalized = hashtag.replaceAll('#', '').trim();
    if (normalized.isEmpty) {
      return;
    }
    textController.text = normalized;
    query.value = normalized;
  }

  void _loadSearchHistory() {
    final list = _storage.read<List>(_historyKey);
    if (list != null) {
      searchHistory.assignAll(list.cast<String>());
    }
  }

  void _saveSearchToHistory(String term) {
    final t = term.trim();
    if (t.isEmpty) return;
    searchHistory.removeWhere((e) => e.toLowerCase() == t.toLowerCase());
    searchHistory.insert(0, t);
    if (searchHistory.length > 10) {
      searchHistory.removeRange(10, searchHistory.length);
    }
    _storage.write(_historyKey, searchHistory.toList());
  }

  void clearSearchHistory() {
    searchHistory.clear();
    _storage.remove(_historyKey);
  }

  void searchFromHistory(String term) {
    final normalized = term.trim();
    if (normalized.isEmpty) {
      return;
    }
    textController.text = normalized;
    query.value = normalized;
  }

  @override
  void onClose() {
    _queryWorker?.dispose();
    textController.dispose();
    super.onClose();
  }

  void clearQuery() {
    textController.clear();
    query.value = '';
    users.clear();
    videos.clear();
  }

  void _applyRouteArguments() {
    final args = Get.arguments;
    if (args is! Map) {
      return;
    }

    if (args['hashtag'] is String) {
      final normalized = (args['hashtag'] as String).replaceAll('#', '').trim();
      if (normalized.isNotEmpty) {
        textController.text = normalized;
        query.value = normalized;
      }
      return;
    }

    if (args['initialQuery'] is String) {
      final normalized = (args['initialQuery'] as String).trim();
      if (normalized.isEmpty) {
        return;
      }
      textController.text = normalized;
      query.value = normalized;
    }
  }
}
