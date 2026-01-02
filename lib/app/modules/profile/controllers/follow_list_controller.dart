import 'package:get/get.dart';
import 'package:snapflow/app/data/models/user_model.dart';
import 'package:snapflow/app/data/repositories/user_repository.dart';
import 'package:snapflow/app/routes/app_routes.dart';

class FollowListController extends GetxController {
  final UserRepository _userRepository = Get.find();

  // Reactive variables
  final users = <UserModel>[].obs;
  final filteredUsers = <UserModel>[].obs;
  final isLoading = false.obs;
  final searchQuery = ''.obs;

  // Parameters
  String? targetUserId;
  String? listType; // 'followers' or 'following'

  @override
  void onInit() {
    super.onInit();

    // Get parameters from arguments
    final args = Get.arguments as Map<String, dynamic>?;
    targetUserId = args?['userId'];
    listType = args?['type'];

    if (targetUserId != null && listType != null) {
      loadUsers();
    }
  }

  Future<void> loadUsers() async {
    try {
      isLoading.value = true;

      List<UserModel> userList = [];

      if (listType == 'followers') {
        userList = await _userRepository.getFollowers(targetUserId!);
      } else if (listType == 'following') {
        userList = await _userRepository.getFollowing(targetUserId!);
      }

      users.assignAll(userList);
      filteredUsers.assignAll(userList);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load users: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void searchUsers(String query) {
    searchQuery.value = query;

    if (query.isEmpty) {
      filteredUsers.assignAll(users);
    } else {
      final filtered = users.where((user) {
        return user.username.toLowerCase().contains(query.toLowerCase()) ||
            user.displayName.toLowerCase().contains(query.toLowerCase());
      }).toList();

      filteredUsers.assignAll(filtered);
    }
  }

  void navigateToProfile(String userId) {
    // Replace current route to reduce stack depth and avoid stale controllers.
    Get.offNamed(Routes.profile, arguments: {'userId': userId});
  }

  Future<void> refreshUsers() async {
    await loadUsers();
  }
}
