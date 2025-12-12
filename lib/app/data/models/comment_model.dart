import 'package:equatable/equatable.dart';

class CommentModel extends Equatable {
  const CommentModel({
    required this.id,
    required this.videoId,
    required this.authorId,
    required this.text,
    required this.createdAt,
  });

  factory CommentModel.empty() => CommentModel(
    id: '',
    videoId: '',
    authorId: '',
    text: '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  final String id;
  final String videoId;
  final String authorId;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'videoId': videoId,
    'authorId': authorId,
    'text': text,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory CommentModel.fromJson(Map<String, dynamic> json) => CommentModel(
    id: json['id'] as String? ?? '',
    videoId: json['videoId'] as String? ?? '',
    authorId: json['authorId'] as String? ?? '',
    text: json['text'] as String? ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      json['createdAt'] as int? ?? 0,
    ),
  );

  @override
  List<Object?> get props => [id, videoId, authorId, text, createdAt];
}
