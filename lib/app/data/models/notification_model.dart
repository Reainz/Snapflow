import 'package:equatable/equatable.dart';

class NotificationModel extends Equatable {
  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.type,
    this.actorUserId,
    this.videoId,
    this.commentId,
    this.payload,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  // Optional rich fields for filtering and UI
  final String? type; // like, comment, follow, share
  final String? actorUserId;
  final String? videoId;
  final String? commentId;
  final Map<String, dynamic>? payload;
  final bool read;

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? createdAt,
    String? type,
    String? actorUserId,
    String? videoId,
    String? commentId,
    Map<String, dynamic>? payload,
    bool? read,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      actorUserId: actorUserId ?? this.actorUserId,
      videoId: videoId ?? this.videoId,
      commentId: commentId ?? this.commentId,
      payload: payload ?? this.payload,
      read: read ?? this.read,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'body': body,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'type': type,
    'actorUserId': actorUserId,
    'videoId': videoId,
    'commentId': commentId,
    'payload': payload,
    'read': read,
  };

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['createdAt'] as int? ?? 0,
      ),
      type: json['type'] as String?,
      actorUserId: json['actorUserId'] as String?,
      videoId: json['videoId'] as String?,
      commentId: json['commentId'] as String?,
      payload: (json['payload'] as Map<String, dynamic>?),
      read: json['read'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, title, body, createdAt, type, actorUserId, videoId, commentId, payload, read];
}
