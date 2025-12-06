import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { checkRateLimit } from '../utils/rate-limiter';
import { getDb } from '../utils/firestore-helpers';
import { logger } from 'firebase-functions/v1';

/**
 * Firestore Triggers for Rate Limiting Social Actions
 * 
 * These triggers run AFTER client-side writes to validate rate limits.
 * If rate limit exceeded, they roll back the write and decrement counters.
 * This provides server-side protection without requiring client changes.
 */

/**
 * Rate Limit Trigger: Video Likes
 * 
 * Triggers when a like is created in videos/{videoId}/likes/{userId}
 * Checks if user has exceeded like rate limit (100/hour)
 * If exceeded: deletes like, decrements likesCount, creates admin alert
 */
export const onLikeCreate = functions.firestore
  .onDocumentCreated('videos/{videoId}/likes/{userId}', async (event) => {
    const { videoId, userId } = event.params;
    const db = getDb();
    
    try {
      // Check rate limit
      const rateLimitResult = await checkRateLimit(userId, 'like');
      
      if (!rateLimitResult.allowed) {
        logger.warn(`Rate limit exceeded for like by user ${userId} on video ${videoId}`);
        
        // Rollback: delete the like document
        await event.data?.ref.delete();
        
        // Decrement video likesCount
        const videoRef = db.collection('videos').doc(videoId);
        await videoRef.update({
          likesCount: admin.firestore.FieldValue.increment(-1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        // Create admin alert for monitoring
        await db.collection('admin_alerts').add({
          type: 'rate_limit_violation',
          action: 'like',
          userId,
          resourceId: videoId,
          message: `User ${userId} exceeded like rate limit`,
          retryAfter: rateLimitResult.retryAfterSeconds,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          severity: 'warning',
        });
        
        logger.info(`Rolled back like from user ${userId} on video ${videoId} due to rate limit`);
      }
    } catch (error) {
      // Log error but don't fail - we want the like to stay if rate check fails (fail-open)
      logger.error('Error checking rate limit for like:', error);
    }
  });

/**
 * Rate Limit Trigger: Comments
 * 
 * Triggers when a comment is created in comments/{commentId}
 * Checks if user has exceeded comment rate limit (20/hour)
 * If exceeded: deletes comment, decrements video commentsCount
 */
export const onCommentCreate = functions.firestore
  .onDocumentCreated('comments/{commentId}', async (event) => {
    const commentData = event.data?.data();
    if (!commentData) return;
    
    const { commentId } = event.params;
    const authorId = commentData.authorId as string;
    const videoId = commentData.videoId as string;
    const db = getDb();
    
    try {
      // Check rate limit
      const rateLimitResult = await checkRateLimit(authorId, 'comment');
      
      if (!rateLimitResult.allowed) {
        logger.warn(`Rate limit exceeded for comment by user ${authorId} on video ${videoId}`);
        
        // Rollback: delete the comment document
        await event.data?.ref.delete();
        
        // Decrement video commentsCount
        const videoRef = db.collection('videos').doc(videoId);
        await videoRef.update({
          commentsCount: admin.firestore.FieldValue.increment(-1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        // Create admin alert
        await db.collection('admin_alerts').add({
          type: 'rate_limit_violation',
          action: 'comment',
          userId: authorId,
          resourceId: videoId,
          message: `User ${authorId} exceeded comment rate limit`,
          retryAfter: rateLimitResult.retryAfterSeconds,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          severity: 'warning',
        });
        
        logger.info(`Rolled back comment ${commentId} from user ${authorId} due to rate limit`);
      }
    } catch (error) {
      logger.error('Error checking rate limit for comment:', error);
    }
  });

/**
 * Rate Limit Trigger: Follows
 * 
 * Triggers when a follow is created in users/{currentUserId}/following/{targetUserId}
 * Checks if user has exceeded follow rate limit (30/hour)
 * If exceeded: deletes both follow docs (following and follower), decrements counts
 */
export const onFollowCreate = functions.firestore
  .onDocumentCreated('users/{currentUserId}/following/{targetUserId}', async (event) => {
    const { currentUserId, targetUserId } = event.params;
    const db = getDb();
    
    try {
      // Check rate limit
      const rateLimitResult = await checkRateLimit(currentUserId, 'follow');
      
      if (!rateLimitResult.allowed) {
        logger.warn(`Rate limit exceeded for follow by user ${currentUserId} -> ${targetUserId}`);
        
        // Rollback: delete both follow documents (following and follower)
        await event.data?.ref.delete();
        await db.collection('users').doc(targetUserId).collection('followers').doc(currentUserId).delete();
        
        // Decrement both user counts
        await db.collection('users').doc(currentUserId).update({
          followingCount: admin.firestore.FieldValue.increment(-1),
        });
        await db.collection('users').doc(targetUserId).update({
          followersCount: admin.firestore.FieldValue.increment(-1),
        });
        
        // Create admin alert
        await db.collection('admin_alerts').add({
          type: 'rate_limit_violation',
          action: 'follow',
          userId: currentUserId,
          resourceId: targetUserId,
          message: `User ${currentUserId} exceeded follow rate limit`,
          retryAfter: rateLimitResult.retryAfterSeconds,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          severity: 'warning',
        });
        
        logger.info(`Rolled back follow from user ${currentUserId} -> ${targetUserId} due to rate limit`);
      }
    } catch (error) {
      logger.error('Error checking rate limit for follow:', error);
    }
  });
