import 'package:equatable/equatable.dart';

class VideoModel extends Equatable {
  const VideoModel({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.hlsUrl,
    required this.thumbnailUrl,
    required this.duration,
    required this.viewsCount,
    required this.likesCount,
    required this.commentsCount,
    required this.isLiked,
    this.captionUrl,
    this.hasCaptions = false,
    this.filterUsed,
    this.hashtags = const [],
    this.privacy,
    this.status,
    this.cloudinaryPublicId,
  });

  factory VideoModel.empty() => const VideoModel(
    id: '',
    ownerId: '',
    title: '',
    description: '',
    hlsUrl: '',
    thumbnailUrl: '',
    duration: 0,
    viewsCount: 0,
    likesCount: 0,
    commentsCount: 0,
    isLiked: false,
    captionUrl: null,
    hasCaptions: false,
    filterUsed: null,
    hashtags: [],
    privacy: null,
    status: null,
    cloudinaryPublicId: null,
  );

  final String id;
  final String ownerId;
  final String title;
  final String description;
  final String hlsUrl;
  final String thumbnailUrl;
  final int duration;
  final int viewsCount;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final String? captionUrl;
  final bool hasCaptions;
  final String? filterUsed;
  final List<String> hashtags;
  final String? privacy;
  final String? status;
  final String? cloudinaryPublicId;

  VideoModel copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? description,
    String? hlsUrl,
    String? thumbnailUrl,
    int? duration,
    int? viewsCount,
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
    String? captionUrl,
    bool? hasCaptions,
    String? filterUsed,
    List<String>? hashtags,
    String? privacy,
    String? status,
    String? cloudinaryPublicId,
  }) {
    return VideoModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      hlsUrl: hlsUrl ?? this.hlsUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      viewsCount: viewsCount ?? this.viewsCount,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      captionUrl: captionUrl ?? this.captionUrl,
      hasCaptions: hasCaptions ?? this.hasCaptions,
      filterUsed: filterUsed ?? this.filterUsed,
      hashtags: hashtags ?? this.hashtags,
      privacy: privacy ?? this.privacy,
      status: status ?? this.status,
      cloudinaryPublicId: cloudinaryPublicId ?? this.cloudinaryPublicId,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'ownerId': ownerId,
    'title': title,
    'description': description,
    'hlsUrl': hlsUrl,
    'thumbnailUrl': thumbnailUrl,
    'duration': duration,
    'viewsCount': viewsCount,
    'likesCount': likesCount,
    'commentsCount': commentsCount,
    'isLiked': isLiked,
    'captionUrl': captionUrl,
    'hasCaptions': hasCaptions,
    'filterUsed': filterUsed,
    'hashtags': hashtags,
    'privacy': privacy,
    'status': status,
    'cloudinaryPublicId': cloudinaryPublicId,
  };

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    List<String> parseHashtags(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    }

    return VideoModel(
      id: json['id'] as String? ?? '',
      ownerId: json['ownerId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      hlsUrl: json['hlsUrl'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      duration: parseInt(json['durationSeconds']),
      viewsCount: parseInt(json['viewsCount']),
      likesCount: parseInt(json['likesCount']),
      commentsCount: parseInt(json['commentsCount']),
      isLiked: json['isLiked'] as bool? ?? false,
      captionUrl: json['captionUrl'] as String?,
      hasCaptions: json['hasCaptions'] as bool? ?? false,
      filterUsed: json['filterUsed'] as String?,
      hashtags: parseHashtags(json['hashtags']),
      privacy: json['privacy'] as String?,
      status: json['status'] as String?,
      cloudinaryPublicId: json['cloudinaryPublicId'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    ownerId,
    title,
    description,
    hlsUrl,
    thumbnailUrl,
    duration,
    viewsCount,
    likesCount,
    commentsCount,
    isLiked,
    captionUrl,
    hasCaptions,
    filterUsed,
    hashtags,
    privacy,
    status,
    cloudinaryPublicId,
  ];
}
