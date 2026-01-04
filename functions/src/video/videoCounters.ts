import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { getDb } from '../utils/firestore-helpers';
import { logger } from 'firebase-functions/v1';

/**
 * Maintains denormalized counters on user documents.
 *
 * The admin dashboard expects `users/{uid}.videosCount` to be accurate, but
 * clients cannot update this field (rules prohibit it). This trigger keeps it in sync.
 */
export const onVideoCreatedUpdateUserCounters = functions.firestore.onDocumentCreated(
  'videos/{videoId}',
  async (event) => {
    const data = event.data?.data() as Record<string, unknown> | undefined;
    if (!data) return;

    const ownerId = data.ownerId as string | undefined;
    if (!ownerId) {
      logger.warn('Video created without ownerId; skipping videosCount increment', {
        videoId: event.params.videoId,
      });
      return;
    }

    const db = getDb();
    try {
      await db
        .collection('users')
        .doc(ownerId)
        .set(
          {
            videosCount: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
    } catch (error: any) {
      logger.error('Failed to increment videosCount for user', {
        ownerId,
        videoId: event.params.videoId,
        error: error?.message || String(error),
      });
    }
  }
);

