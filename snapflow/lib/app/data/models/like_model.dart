import 'package:equatable/equatable.dart';

class LikeModel extends Equatable {
  const LikeModel({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.createdAt,
  });

  factory LikeModel.empty() => LikeModel(
    id: '',
    videoId: '',
    userId: '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  final String id;
  final String videoId;
  final String userId;
  final DateTime createdAt;

  LikeModel copyWith({
    String? id,
    String? videoId,
    String? userId,
    DateTime? createdAt,
  }) {
    return LikeModel(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'videoId': videoId,
    'userId': userId,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory LikeModel.fromJson(Map<String, dynamic> json) => LikeModel(
    id: json['id'] as String? ?? '',
    videoId: json['videoId'] as String? ?? '',
    userId: json['userId'] as String? ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      json['createdAt'] as int? ?? 0,
    ),
  );

  @override
  List<Object?> get props => [id, videoId, userId, createdAt];
}
