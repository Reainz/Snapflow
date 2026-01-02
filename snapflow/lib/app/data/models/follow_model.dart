import 'package:equatable/equatable.dart';

class FollowModel extends Equatable {
  const FollowModel({
    required this.id,
    required this.followerId,
    required this.followingId,
    required this.createdAt,
  });

  factory FollowModel.empty() => FollowModel(
    id: '',
    followerId: '',
    followingId: '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  final String id;
  final String followerId;
  final String followingId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'followerId': followerId,
    'followingId': followingId,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory FollowModel.fromJson(Map<String, dynamic> json) => FollowModel(
    id: json['id'] as String? ?? '',
    followerId: json['followerId'] as String? ?? '',
    followingId: json['followingId'] as String? ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      json['createdAt'] as int? ?? 0,
    ),
  );

  @override
  List<Object?> get props => [id, followerId, followingId, createdAt];
}
