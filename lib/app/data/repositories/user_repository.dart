import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_queue_service.dart';

import '../models/user_model.dart';

/// Simple page object for users pagination.
class UserPage {
  UserPage({required this.items, this.lastDoc, required this.hasMore});
  final List<UserModel> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
}

class UserRepository extends GetxService {
  // Lazy access to FirebaseFirestore to avoid requiring Firebase initialization
  // at construction time (useful for widget tests that don't init Firebase).
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<UserModel> getCurrentUser() async {
    // TODO: Fetch from Firestore once Firebase is configured.
    return UserModel.empty();
  }

  Future<UserModel> getUserById(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final data = userDoc.data() ?? <String, dynamic>{};
      return UserModel.fromJson({
        ...data,
        'id': userDoc.id,
      });
    } catch (e) {
      throw Exception('Failed to fetch user: $e');
    }
  }

  Future<void> createUserProfile({
    required String userId,
    required String email,
    String username = '',
    String displayName = '',
    String? countryCode,
    String? region,
  }) async {
    try {
      final userDoc = _firestore.collection('users').doc(userId);

      // Create user profile document
      await userDoc.set({
        'id': userId,
        'email': email,
        'username': username.isEmpty ? email.split('@')[0] : username,
        'displayName': displayName.isEmpty ? email.split('@')[0] : displayName,
        'displayNameLower': (displayName.isEmpty ? email.split('@')[0] : displayName).toLowerCase(),
        'avatarUrl': '',
        'bio': '',
        'website': '',
        'location': '',
        if (countryCode != null) 'countryCode': countryCode,
        if (region != null) 'region': region,
        'followersCount': 0,
        'followingCount': 0,
        'videosCount': 0,
        'isAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Used by admin analytics for DAU/WAU/MAU (updated on app start/login).
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to create user profile: $e');
    }
  }

  // ===== Admin dashboard helpers =====

  Future<int> getAllUsersCount() async {
    final countSnap = await _firestore.collection('users').count().get();
    return countSnap.count ?? 0;
  }

  Future<int> getActiveUsersCount({required int hours}) async {
    final since = DateTime.now().subtract(Duration(hours: hours));
    // We assume 'updatedAt' moves on user activity; if not, replace with a tracked 'lastActiveAt'
    final snap = await _firestore
        .collection('users')
        .where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .count()
        .get();
    return snap.count ?? 0;
  }

  /// Counts active users whose updatedAt is within [start]..[end] (inclusive bounds).
  Future<int> getActiveUsersCountBetween({required DateTime start, required DateTime end}) async {
    final snap = await _firestore
        .collection('users')
        .where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('updatedAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .count()
        .get();
    return snap.count ?? 0;
  }

  Future<List<UserModel>> getRecentUsers({int limit = 10}) async {
    final snap = await _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return UserModel.fromJson(data);
    }).toList();
  }

  Future<void> banUser(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'status': 'banned',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteUser(String userId) async {
    await _firestore.collection('users').doc(userId).delete();
  }

  Future<Map<String, int>> getUserGrowthData(DateTime startDate, DateTime endDate) async {
    // Aggregate by day
    final snap = await _firestore
        .collection('users')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('createdAt')
        .get();
    final map = <String, int>{};
    for (final d in snap.docs) {
      final ts = d.data()['createdAt'] as Timestamp?;
      if (ts == null) continue;
      final date = ts.toDate();
      final key = DateTime(date.year, date.month, date.day).toIso8601String();
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  /// Fetch a page of users ordered by [orderBy] field.
  /// Supported fields typically: 'createdAt', 'displayNameLower', 'followersCount'.
  Future<UserPage> getUsersPage({
    int limit = 20,
    String orderBy = 'createdAt',
    bool descending = true,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection('users').orderBy(orderBy, descending: descending).limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get();
    final docs = snap.docs;
    final items = docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return UserModel.fromJson(data);
    }).toList();

    final lastDoc = docs.isNotEmpty ? docs.last : null;
    final hasMore = docs.length == limit;
    return UserPage(items: items, lastDoc: lastDoc, hasMore: hasMore);
  }

  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('users').doc(userId).update(updates);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  Future<List<UserModel>> searchUsers(String query, {int limit = 20}) async {
    try {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) return [];

      // Strategy: prefix match on username and displayNameLower
    final usernameSnap = await _firestore
      .collection('users')
      .where('username', isGreaterThanOrEqualTo: q)
      .where('username', isLessThan: '$q\uf8ff')
      .limit(limit)
      .get();

    final nameSnap = await _firestore
      .collection('users')
      .where('displayNameLower', isGreaterThanOrEqualTo: q)
      .where('displayNameLower', isLessThan: '$q\uf8ff')
      .limit(limit)
      .get();

      final docs = <DocumentSnapshot<Map<String, dynamic>>>[
        ...usernameSnap.docs,
        ...nameSnap.docs,
      ];

      final seen = <String>{};
      final users = <UserModel>[];
      for (final d in docs) {
        if (seen.add(d.id)) {
          users.add(UserModel.fromJson(d.data()!..putIfAbsent('id', () => d.id)));
        }
      }
      return users.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  Future<void> toggleFollow(String currentUserId, String targetUserId) async {
    // If offline, enqueue persisted action to retry later and return early
    try {
      if (Get.find<ConnectivityService>().isOnline.value == false) {
        await Get.find<OfflineQueueService>().enqueueAction(
          OfflineAction(
            type: OfflineActionType.userToggleFollow,
            payload: {
              'currentUserId': currentUserId,
              'targetUserId': targetUserId,
            },
          ),
        );
        return;
      }
      final batch = _firestore.batch();

      // Check if already following
      final followDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId)
          .get();

      final isFollowing = followDoc.exists;

      if (isFollowing) {
        // Unfollow
        batch.delete(followDoc.reference);
        batch.delete(
          _firestore
              .collection('users')
              .doc(targetUserId)
              .collection('followers')
              .doc(currentUserId),
        );

        // Decrement counts
        batch.update(_firestore.collection('users').doc(currentUserId), {
          'followingCount': FieldValue.increment(-1),
        });
        batch.update(_firestore.collection('users').doc(targetUserId), {
          'followersCount': FieldValue.increment(-1),
        });
      } else {
        // Follow
        batch.set(
          _firestore
              .collection('users')
              .doc(currentUserId)
              .collection('following')
              .doc(targetUserId),
          {'userId': targetUserId, 'createdAt': FieldValue.serverTimestamp()},
        );
        batch.set(
          _firestore
              .collection('users')
              .doc(targetUserId)
              .collection('followers')
              .doc(currentUserId),
          {'userId': currentUserId, 'createdAt': FieldValue.serverTimestamp()},
        );

        // Increment counts
        batch.update(_firestore.collection('users').doc(currentUserId), {
          'followingCount': FieldValue.increment(1),
        });
        batch.update(_firestore.collection('users').doc(targetUserId), {
          'followersCount': FieldValue.increment(1),
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to toggle follow: $e');
    }
  }

  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    try {
      final followDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId)
          .get();

      return followDoc.exists;
    } catch (e) {
      return false;
    }
  }

  Future<List<UserModel>> getFollowers(String userId, {int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .limit(limit)
          .get();

      final userIds = snapshot.docs
          .map((doc) => doc.data()['userId'] as String)
          .toList();

      if (userIds.isEmpty) return [];

      final users = <UserModel>[];
      for (final id in userIds) {
        try {
          final user = await getUserById(id);
          users.add(user);
        } catch (e) {
          // Skip users that can't be loaded
        }
      }

      return users;
    } catch (e) {
      throw Exception('Failed to get followers: $e');
    }
  }

  Future<List<UserModel>> getFollowing(String userId, {int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .limit(limit)
          .get();

      final userIds = snapshot.docs
          .map((doc) => doc.data()['userId'] as String)
          .toList();

      if (userIds.isEmpty) return [];

      final users = <UserModel>[];
      for (final id in userIds) {
        try {
          final user = await getUserById(id);
          users.add(user);
        } catch (e) {
          // Skip users that can't be loaded
        }
      }

      return users;
    } catch (e) {
      throw Exception('Failed to get following: $e');
    }
  }

  Stream<UserModel?> getUserStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        data['id'] = snapshot.id; // Add the document ID
        return UserModel.fromJson(data);
      }
      return null;
    });
  }

  /// Returns trending creators. Simple heuristic: users with highest followersCount.
  /// Future improvement: weigh by recent video uploads or views/likes in last 7 days.
  Future<List<UserModel>> getTrendingCreators({int limit = 10}) async {
    try {
      final snap = await _firestore
          .collection('users')
          .orderBy('followersCount', descending: true)
          .limit(limit)
          .get();

      return snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return UserModel.fromJson(data);
      }).toList();
    } on FirebaseException catch (e) {
      // Fallback: if index/order not allowed, just return empty list
      Get.log('getTrendingCreators failed: ${e.message}', isError: true);
      return [];
    } catch (e) {
      return [];
    }
  }
}
