import 'package:get/get.dart';

import '../modules/auth/bindings/auth_binding.dart';
import '../modules/auth/views/auth_view.dart';
import '../modules/auth/views/login_view.dart';
import '../modules/auth/views/signup_view.dart';
import '../modules/comments/bindings/comments_binding.dart';
import '../modules/comments/views/comments_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/messaging/bindings/messaging_binding.dart';
import '../modules/messaging/views/messaging_view.dart';
import '../modules/notifications/bindings/notifications_binding.dart';
import '../modules/notifications/views/notifications_view.dart';
import '../modules/notifications/views/notification_settings_view.dart';
import '../modules/profile/bindings/profile_binding.dart';
import '../modules/profile/bindings/follow_list_binding.dart';
import '../modules/profile/views/profile_view.dart';
import '../modules/profile/views/edit_profile_view.dart';
import '../modules/profile/views/followers_view.dart';
import '../modules/profile/views/following_view.dart';
import '../modules/search/bindings/search_binding.dart';
import '../modules/search/views/search_view.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/splash/views/splash_view.dart';
import '../modules/video_feed/bindings/video_feed_binding.dart';
import '../modules/video_feed/views/video_feed_view.dart';
import '../modules/video_player/bindings/filtered_video_feed_binding.dart';
import '../modules/video_player/views/filtered_video_feed_view.dart';
import '../modules/video_upload/bindings/video_upload_binding.dart';
import '../modules/video_upload/views/video_upload_view.dart';
import '../modules/video_upload/views/video_post_view.dart';

import 'app_routes.dart';
import '../routes/middlewares/auth_middleware.dart';

class AppPages {
  AppPages._();

  static const initial = Routes.splash;

  static final routes = <GetPage<dynamic>>[
    GetPage(
      name: Routes.splash,
      page: SplashView.new,
      binding: SplashBinding(),
    ),
    GetPage(name: Routes.auth, page: AuthView.new, binding: AuthBinding()),
    GetPage(name: Routes.login, page: LoginView.new, binding: AuthBinding()),
    GetPage(name: Routes.signup, page: SignupView.new, binding: AuthBinding()),
    GetPage(name: Routes.home, page: HomeView.new, binding: HomeBinding()),
    GetPage(
      name: Routes.videoFeed,
      page: VideoFeedView.new,
      binding: VideoFeedBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.filteredVideoFeed,
      page: FilteredVideoFeedView.new,
      binding: FilteredVideoFeedBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.videoUpload,
      page: VideoUploadView.new,
      binding: VideoUploadBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.videoPost,
      page: VideoPostView.new,
      binding: VideoUploadBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.profile,
      page: ProfileView.new,
      binding: ProfileBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.editProfile,
      page: EditProfileView.new,
      binding: ProfileBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.followers,
      page: FollowersView.new,
      binding: FollowListBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.following,
      page: FollowingView.new,
      binding: FollowListBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.comments,
      page: CommentsView.new,
      binding: CommentsBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.search,
      page: SearchView.new,
      binding: SearchBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.notifications,
      page: NotificationsView.new,
      binding: NotificationsBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.notificationsSettings,
      page: NotificationSettingsView.new,
      binding: NotificationsBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.messaging,
      page: MessagingView.new,
      binding: MessagingBinding(),
      middlewares: [AuthMiddleware()],
    ),
  ];
}
