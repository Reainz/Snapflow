import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  const UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
    this.website = '',
    this.location = '',
    this.countryCode,
    this.region,
    this.followersCount = 0,
    this.followingCount = 0,
    this.videosCount = 0,
    this.isAdmin = false,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.empty() => const UserModel(
    id: '',
    username: '',
    displayName: '',
    avatarUrl: '',
    bio: '',
    website: '',
    location: '',
    countryCode: null,
    region: null,
    followersCount: 0,
    followingCount: 0,
    videosCount: 0,
    isAdmin: false,
  );

  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String bio;
  final String website;
  final String location;
  final String? countryCode;
  final String? region;
  final int followersCount;
  final int followingCount;
  final int videosCount;
  final bool isAdmin;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    String? website,
    String? location,
    String? countryCode,
    String? region,
    int? followersCount,
    int? followingCount,
    int? videosCount,
    bool? isAdmin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      website: website ?? this.website,
      location: location ?? this.location,
      countryCode: countryCode ?? this.countryCode,
      region: region ?? this.region,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      videosCount: videosCount ?? this.videosCount,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'username': username,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'bio': bio,
    'website': website,
    'location': location,
    if (countryCode != null) 'countryCode': countryCode,
    if (region != null) 'region': region,
    'followersCount': followersCount,
    'followingCount': followingCount,
    'videosCount': videosCount,
    'isAdmin': isAdmin,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      // Firestore Timestamp type support without importing Firestore here
      final type = v.runtimeType.toString();
      if (type == 'Timestamp') {
        try {
          final milliseconds = (v.millisecondsSinceEpoch as int?);
          if (milliseconds != null) {
            return DateTime.fromMillisecondsSinceEpoch(milliseconds);
          }
          // Some Timestamp expose toDate()
          final toDate = (v as dynamic).toDate();
          if (toDate is DateTime) return toDate;
        } catch (_) {}
      }
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) {
        return DateTime.tryParse(v);
      }
      return null;
    }
    return UserModel(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      website: json['website'] as String? ?? '',
      location: json['location'] as String? ?? '',
      countryCode: json['countryCode'] as String?,
      region: json['region'] as String?,
      followersCount: json['followersCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
      videosCount: json['videosCount'] as int? ?? 0,
      isAdmin: json['isAdmin'] as bool? ?? false,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    username,
    displayName,
    avatarUrl,
    bio,
    website,
    location,
    countryCode,
    region,
    followersCount,
    followingCount,
    videosCount,
    isAdmin,
    createdAt,
    updatedAt,
  ];
}
