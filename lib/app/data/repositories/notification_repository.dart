import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';

import '../models/notification_model.dart';

enum AppNotificationType { like, comment, follow, share }

class NotificationRepository extends GetxService {
  FirebaseFirestore? _firestore;

  FirebaseFirestore? get _db {
    if (_firestore != null) return _firestore;
    if (Firebase.apps.isEmpty) return null;
    _firestore = FirebaseFirestore.instance;
    return _firestore;
  }

  CollectionReference<Map<String, dynamic>> _userNotificationsCol(String userId) {
    final db = _db;
    if (db == null) {
      // Return a dummy collection reference is not possible; callers must guard.
      throw StateError('Firestore is not initialized');
    }
    return db.collection('users').doc(userId).collection('notifications');
  }

  /// Create a notification document under users/{recipientUserId}/notifications
  Future<void> createNotification({
    required String recipientUserId,
    required AppNotificationType type,
    required String actorUserId,
    String? actorDisplayName,
    String? videoId,
    String? commentId,
    String? title,
    String? body,
    Map<String, dynamic>? payload,
  }) async {
    // Do not notify self
    if (recipientUserId.isEmpty ||
        actorUserId.isEmpty ||
        recipientUserId == actorUserId) {
      return;
    }

    // Skip in environments where Firebase isn't initialized (e.g., widget tests)
    if (Firebase.apps.isEmpty) return;

    // Respect recipient preferences
    final prefs = await getUserNotificationPreferences(recipientUserId);
    final allow = switch (type) {
      AppNotificationType.like => prefs.notifyLikes,
      AppNotificationType.comment => prefs.notifyComments,
      AppNotificationType.follow => prefs.notifyFollows,
      AppNotificationType.share => prefs.notifyShares,
    };
    if (!allow) return;

    final displayLabel = (actorDisplayName ?? '').trim().isNotEmpty
        ? actorDisplayName!.trim()
        : 'Someone';

    final data = <String, dynamic>{
      'type': type.name,
      'actorUserId': actorUserId,
      if (actorDisplayName != null && actorDisplayName.trim().isNotEmpty)
        'actorDisplayName': actorDisplayName.trim(),
      if (videoId != null && videoId.isNotEmpty) 'videoId': videoId,
      if (commentId != null && commentId.isNotEmpty) 'commentId': commentId,
      'title': title ?? _defaultTitle(type),
      'body': body ?? _defaultBody(type, displayLabel),
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      if (payload != null) 'payload': payload,
    };

    await _userNotificationsCol(recipientUserId).add(data);
  }

  /// Stream notifications for a user ordered by createdAt desc
  Stream<List<NotificationModel>> notificationsStream(String userId, {int limit = 50}) {
    if (Firebase.apps.isEmpty) {
      return Stream<List<NotificationModel>>.value(const <NotificationModel>[]);
    }
    return _userNotificationsCol(userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) {
              final data = d.data();
              return NotificationModel(
                id: d.id,
                title: (data['title'] as String?) ?? '',
                body: (data['body'] as String?) ?? '',
                createdAt: _toDateTime(data['createdAt']),
                type: data['type'] as String?,
                actorUserId: data['actorUserId'] as String?,
                videoId: data['videoId'] as String?,
                commentId: data['commentId'] as String?,
                payload: (data['payload'] as Map<String, dynamic>?),
                read: (data['read'] as bool?) ?? false,
              );
            }).toList());
  }

  Future<void> markAsRead({required String userId, required String notificationId}) async {
    if (Firebase.apps.isEmpty) return;
    await _userNotificationsCol(userId).doc(notificationId).update({'read': true});
  }

  Future<void> markAllAsRead({required String userId}) async {
    if (Firebase.apps.isEmpty) return;
    final db = _db!;
    final batch = db.batch();
    final qs = await _userNotificationsCol(userId).where('read', isEqualTo: false).get();
    for (final doc in qs.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  static DateTime _toDateTime(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return DateTime.now();
  }

  String _defaultTitle(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.like:
        return 'New Like';
      case AppNotificationType.comment:
        return 'New Comment';
      case AppNotificationType.follow:
        return 'New Follower';
      case AppNotificationType.share:
        return 'Video Shared';
    }
  }

  String _defaultBody(AppNotificationType type, String actorLabel) {
    switch (type) {
      case AppNotificationType.like:
        return '$actorLabel liked your video.';
      case AppNotificationType.comment:
        return '$actorLabel commented on your video.';
      case AppNotificationType.follow:
        return '$actorLabel started following you.';
      case AppNotificationType.share:
        return '$actorLabel shared your video.';
    }
  }

  // ===== Notification preferences =====
  Future<NotificationPreferences> getUserNotificationPreferences(String userId) async {
    if (Firebase.apps.isEmpty) return const NotificationPreferences();
    try {
      final userDoc = await _db!.collection('users').doc(userId).get();
      final data = userDoc.data() ?? <String, dynamic>{};
      final prefs = (data['notificationPrefs'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      return NotificationPreferences(
        notifyLikes: (prefs['likes'] as bool?) ?? true,
        notifyComments: (prefs['comments'] as bool?) ?? true,
        notifyFollows: (prefs['follows'] as bool?) ?? true,
        notifyShares: (prefs['shares'] as bool?) ?? true,
      );
    } catch (_) {
      return const NotificationPreferences();
    }
  }

  Future<void> setUserNotificationPreferences(String userId, NotificationPreferences prefs) async {
    if (Firebase.apps.isEmpty) return;
    await _db!.collection('users').doc(userId).set({
      'notificationPrefs': {
        'likes': prefs.notifyLikes,
        'comments': prefs.notifyComments,
        'follows': prefs.notifyFollows,
        'shares': prefs.notifyShares,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class NotificationPreferences {
  const NotificationPreferences({
    this.notifyLikes = true,
    this.notifyComments = true,
    this.notifyFollows = true,
    this.notifyShares = true,
  });

  final bool notifyLikes;
  final bool notifyComments;
  final bool notifyFollows;
  final bool notifyShares;

  NotificationPreferences copyWith({
    bool? notifyLikes,
    bool? notifyComments,
    bool? notifyFollows,
    bool? notifyShares,
  }) => NotificationPreferences(
        notifyLikes: notifyLikes ?? this.notifyLikes,
        notifyComments: notifyComments ?? this.notifyComments,
        notifyFollows: notifyFollows ?? this.notifyFollows,
        notifyShares: notifyShares ?? this.notifyShares,
      );
}
