import '../../video_feed/controllers/video_feed_controller.dart';

class FollowersFeedController extends VideoFeedController {
  FollowersFeedController() : super(feedType: FeedType.followers);
}
