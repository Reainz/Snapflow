import * as functions from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { checkRateLimit } from '../utils/rate-limiter';
import { getDb } from '../utils/firestore-helpers';
import { logger } from 'firebase-functions/v1';

/**
 * Cloud Function: Flag Video
 * 
 * HTTP Callable function for flagging inappropriate videos
 * Checks rate limit (10 flags per 24 hours) before allowing flag
 * 
 * Parameters:
 * - videoId: string - ID of the video to flag
 * 
 * Returns:
 * - success: boolean
 * - message: string
 * 
 * Throws:
 * - unauthenticated: if user not logged in
 * - failed-precondition: if rate limit exceeded
 * - not-found: if video doesn't exist
 */
export const flagVideo = functions.onCall(async (request) => {
  // Check authentication
  if (!request.auth) {
    throw new functions.HttpsError(
      'unauthenticated',
      'User must be authenticated to flag videos'
    );
  }

  const userId = request.auth.uid;
  const { videoId } = request.data;

  // Validate input
  if (!videoId || typeof videoId !== 'string') {
    throw new functions.HttpsError(
      'invalid-argument',
      'videoId is required and must be a string'
    );
  }

  const db = getDb();

  try {
    // Check rate limit for flag action (10 per 24 hours)
    const rateLimitResult = await checkRateLimit(userId, 'flag');

    if (!rateLimitResult.allowed) {
      logger.warn(`Rate limit exceeded for flag by user ${userId} on video ${videoId}`);
      
      // Calculate retry time
      const retryAfterMinutes = Math.ceil((rateLimitResult.retryAfterSeconds || 0) / 60);
      
      throw new functions.HttpsError(
        'failed-precondition',
        `Flag limit reached. You can flag videos again in ${retryAfterMinutes} minutes.`,
        { retryAfterSeconds: rateLimitResult.retryAfterSeconds }
      );
    }

    // Check if video exists
    const videoRef = db.collection('videos').doc(videoId);
    const videoDoc = await videoRef.get();

    if (!videoDoc.exists) {
      throw new functions.HttpsError(
        'not-found',
        `Video ${videoId} not found`
      );
    }

    // Update video to flagged status
    await videoRef.update({
      status: 'flagged',
      flaggedAt: admin.firestore.FieldValue.serverTimestamp(),
      flaggedBy: userId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Create admin alert for moderation queue
    await db.collection('admin_alerts').add({
      type: 'content_flagged',
      action: 'flag',
      userId,
      resourceId: videoId,
      message: `Video ${videoId} flagged by user ${userId}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      severity: 'info',
      acknowledged: false,
    });

    logger.info(`Video ${videoId} flagged by user ${userId}`);

    return {
      success: true,
      message: 'Video flagged successfully. Our moderation team will review it.',
    };
  } catch (error) {
    // Re-throw HttpsError as-is
    if (error instanceof functions.HttpsError) {
      throw error;
    }

    // Log and wrap other errors
    logger.error('Error flagging video:', error);
    throw new functions.HttpsError(
      'internal',
      'Failed to flag video. Please try again later.'
    );
  }
});
