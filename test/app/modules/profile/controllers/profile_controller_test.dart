import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snapflow/app/core/services/auth_service.dart';
import 'package:snapflow/app/core/services/social_service.dart';
import 'package:snapflow/app/data/models/user_model.dart';
import 'package:snapflow/app/data/repositories/user_repository.dart';
import 'package:snapflow/app/data/repositories/video_repository.dart';
import 'package:snapflow/app/modules/profile/controllers/profile_controller.dart';

class MockVideoRepository extends Mock implements VideoRepository {}
class MockUserRepository extends Mock implements UserRepository {}
class MockAuthService extends Mock implements AuthService {}
class MockSocialService extends Mock implements SocialService {}

void main() {
  late ProfileController controller;
  late MockVideoRepository mockVideoRepository;
  late MockUserRepository mockUserRepository;
  late MockAuthService mockAuthService;
  late MockSocialService mockSocialService;

  setUp(() {
    Get.testMode = true;
    mockVideoRepository = MockVideoRepository();
    mockUserRepository = MockUserRepository();
    mockAuthService = MockAuthService();
    mockSocialService = MockSocialService();

    Get.put<VideoRepository>(mockVideoRepository);
    Get.put<UserRepository>(mockUserRepository);
    Get.put<AuthService>(mockAuthService);
    Get.put<SocialService>(mockSocialService);

    // Mock default behaviors
    when(() => mockAuthService.currentUser).thenReturn(Rx(UserModel.empty().copyWith(id: 'currentUser')));
    when(() => mockUserRepository.getUserById(any())).thenAnswer((_) async => UserModel.empty());
    when(() => mockVideoRepository.getUserVideosPage(any(), limit: any(named: 'limit'), startAfter: any(named: 'startAfter'), isOwnProfile: any(named: 'isOwnProfile'), viewerFollowsOwner: any(named: 'viewerFollowsOwner')))
        .thenAnswer((_) async => VideoPage(items: [], hasMore: false));
    when(() => mockVideoRepository.likedVideoIdsStream(any())).thenAnswer((_) => Stream.value([]));
    when(() => mockVideoRepository.savedVideoIdsStream(any())).thenAnswer((_) => Stream.value([]));
    when(() => mockUserRepository.getUserStream(any())).thenAnswer((_) => Stream.value(null));

    controller = ProfileController();
    // Initialize controller with a target user
    controller.targetUserId = 'targetUser';
  });

  tearDown(() {
    Get.reset();
  });

  group('ProfileController - Cache Invalidation', () {
    test('should invalidate following cache when user follows successfully', () async {
      // Arrange
      final currentUserId = 'currentUser';
      final targetUserId = 'targetUser';
      
      // Setup auth user
      when(() => mockAuthService.currentUser).thenReturn(Rx(UserModel.empty().copyWith(id: currentUserId)));
      
      // Setup initial state
      controller.isFollowing.value = false;
      controller.user.value = UserModel.empty().copyWith(id: targetUserId, followersCount: 10);

      // Mock social service to return true (followed)
      when(() => mockSocialService.toggleFollow(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
      )).thenAnswer((_) async => true);

      // Act
      await controller.toggleFollow(targetUserId);

      // Assert
      verify(() => mockVideoRepository.invalidateFollowingCache(currentUserId)).called(1);
      verifyNever(() => mockVideoRepository.clearFollowingCache());
    });

    test('should clear following cache when user unfollows successfully', () async {
      // Arrange
      final currentUserId = 'currentUser';
      final targetUserId = 'targetUser';
      
      // Setup auth user
      when(() => mockAuthService.currentUser).thenReturn(Rx(UserModel.empty().copyWith(id: currentUserId)));
      
      // Setup initial state
      controller.isFollowing.value = true;
      controller.user.value = UserModel.empty().copyWith(id: targetUserId, followersCount: 10);

      // Mock social service to return false (unfollowed)
      when(() => mockSocialService.toggleFollow(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
      )).thenAnswer((_) async => false);

      // Act
      await controller.toggleFollow(targetUserId);

      // Assert
      verify(() => mockVideoRepository.clearFollowingCache()).called(1);
      verifyNever(() => mockVideoRepository.invalidateFollowingCache(any()));
    });

    test('should handle cache invalidation errors gracefully', () async {
      // Arrange
      final currentUserId = 'currentUser';
      final targetUserId = 'targetUser';
      
      // Setup auth user
      when(() => mockAuthService.currentUser).thenReturn(Rx(UserModel.empty().copyWith(id: currentUserId)));
      
      // Mock social service to return true (followed)
      when(() => mockSocialService.toggleFollow(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
      )).thenAnswer((_) async => true);

      // Mock cache invalidation to throw error
      when(() => mockVideoRepository.invalidateFollowingCache(any())).thenThrow(Exception('Cache error'));

      // Act
      await controller.toggleFollow(targetUserId);

      // Assert
      // Should not throw exception and should still update UI
      expect(controller.isFollowing.value, true);
      verify(() => mockVideoRepository.invalidateFollowingCache(currentUserId)).called(1);
    });
  });
}
