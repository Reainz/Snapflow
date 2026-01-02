import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_queue_service.dart';

import '../models/comment_model.dart';

class CommentsRepository extends GetxService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Stream<List<CommentModel>> watchComments(String videoId) {
    return _firestore
        .collection('comments')
        .where('videoId', isEqualTo: videoId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              final ts = data['createdAt'];
              final createdAt = ts is Timestamp
                  ? ts.toDate()
                  : DateTime.fromMillisecondsSinceEpoch(
                      (ts as int?) ?? 0,
                    );
              return CommentModel(
                id: d.id,
                videoId: data['videoId'] as String? ?? '',
                authorId: data['authorId'] as String? ?? '',
                text: data['text'] as String? ?? '',
                createdAt: createdAt,
              );
            }).toList());
  }

  Future<void> addComment({
    required String videoId,
    required String authorId,
    required String text,
  }) async {
    // Use batch write to atomically create comment and increment video's commentsCount
    final batch = _firestore.batch();
    
    // Create comment document
    final commentRef = _firestore.collection('comments').doc();
    batch.set(commentRef, {
      'videoId': videoId,
      'authorId': authorId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Increment video's commentsCount
    final videoRef = _firestore.collection('videos').doc(videoId);
    batch.update(videoRef, {
      'commentsCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    // Commit batch atomically
    await batch.commit();
  }

  /// Toggle like on a comment
  Future<bool> toggleCommentLike({
    required String commentId,
    required String userId,
  }) async {
    // If offline, enqueue persisted action and return optimistic 'liked'
    final online = Get.find<ConnectivityService>().isOnline.value;
    if (!online) {
      await Get.find<OfflineQueueService>().enqueueAction(
        OfflineAction(
          type: OfflineActionType.commentToggleLike,
          payload: {'commentId': commentId, 'userId': userId},
        ),
      );
      return true;
    }
    final likeRef = _firestore
        .collection('comments')
        .doc(commentId)
        .collection('likes')
        .doc(userId);
    
    final snap = await likeRef.get();
    if (snap.exists) {
      await likeRef.delete();
      return false; // unliked
    } else {
      await likeRef.set({
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true; // liked
    }
  }

  /// Stream to check if user liked a comment
  Stream<bool> isCommentLikedStream({
    required String commentId,
    required String userId,
  }) {
    return _firestore
        .collection('comments')
        .doc(commentId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Stream for comment likes count
  Stream<int> commentLikesCountStream(String commentId) {
    return _firestore
        .collection('comments')
        .doc(commentId)
        .collection('likes')
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Delete a comment
  Future<void> deleteComment(String commentId) async {
    await _firestore.collection('comments').doc(commentId).delete();
  }

  /// Update comment text
  Future<void> updateComment({
    required String commentId,
    required String text,
  }) async {
    await _firestore.collection('comments').doc(commentId).update({
      'text': text,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
