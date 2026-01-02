"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onFollowCreate = exports.onCommentCreate = exports.onLikeCreate = void 0;
const functions = __importStar(require("firebase-functions/v2"));
const admin = __importStar(require("firebase-admin"));
const rate_limiter_1 = require("../utils/rate-limiter");
const firestore_helpers_1 = require("../utils/firestore-helpers");
const v1_1 = require("firebase-functions/v1");
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
exports.onLikeCreate = functions.firestore
    .onDocumentCreated('videos/{videoId}/likes/{userId}', async (event) => {
    const { videoId, userId } = event.params;
    const db = (0, firestore_helpers_1.getDb)();
    try {
        // Check rate limit
        const rateLimitResult = await (0, rate_limiter_1.checkRateLimit)(userId, 'like');
        if (!rateLimitResult.allowed) {
            v1_1.logger.warn(`Rate limit exceeded for like by user ${userId} on video ${videoId}`);
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
            v1_1.logger.info(`Rolled back like from user ${userId} on video ${videoId} due to rate limit`);
        }
    }
    catch (error) {
        // Log error but don't fail - we want the like to stay if rate check fails (fail-open)
        v1_1.logger.error('Error checking rate limit for like:', error);
    }
});
/**
 * Rate Limit Trigger: Comments
 *
 * Triggers when a comment is created in comments/{commentId}
 * Checks if user has exceeded comment rate limit (20/hour)
 * If exceeded: deletes comment, decrements video commentsCount
 */
exports.onCommentCreate = functions.firestore
    .onDocumentCreated('comments/{commentId}', async (event) => {
    const commentData = event.data?.data();
    if (!commentData)
        return;
    const { commentId } = event.params;
    const authorId = commentData.authorId;
    const videoId = commentData.videoId;
    const db = (0, firestore_helpers_1.getDb)();
    try {
        // Check rate limit
        const rateLimitResult = await (0, rate_limiter_1.checkRateLimit)(authorId, 'comment');
        if (!rateLimitResult.allowed) {
            v1_1.logger.warn(`Rate limit exceeded for comment by user ${authorId} on video ${videoId}`);
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
            v1_1.logger.info(`Rolled back comment ${commentId} from user ${authorId} due to rate limit`);
        }
    }
    catch (error) {
        v1_1.logger.error('Error checking rate limit for comment:', error);
    }
});
/**
 * Rate Limit Trigger: Follows
 *
 * Triggers when a follow is created in users/{currentUserId}/following/{targetUserId}
 * Checks if user has exceeded follow rate limit (30/hour)
 * If exceeded: deletes both follow docs (following and follower), decrements counts
 */
exports.onFollowCreate = functions.firestore
    .onDocumentCreated('users/{currentUserId}/following/{targetUserId}', async (event) => {
    const { currentUserId, targetUserId } = event.params;
    const db = (0, firestore_helpers_1.getDb)();
    try {
        // Check rate limit
        const rateLimitResult = await (0, rate_limiter_1.checkRateLimit)(currentUserId, 'follow');
        if (!rateLimitResult.allowed) {
            v1_1.logger.warn(`Rate limit exceeded for follow by user ${currentUserId} -> ${targetUserId}`);
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
            v1_1.logger.info(`Rolled back follow from user ${currentUserId} -> ${targetUserId} due to rate limit`);
        }
    }
    catch (error) {
        v1_1.logger.error('Error checking rate limit for follow:', error);
    }
});
//# sourceMappingURL=rateLimitTriggers.js.map