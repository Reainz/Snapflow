import * as admin from 'firebase-admin';
import { getDb } from './firestore-helpers';
import { logger } from 'firebase-functions';

export type RateLimitAction = 'upload' | 'comment' | 'like' | 'follow' | 'share' | 'flag';
export type RateLimitWindow = 'hourly' | 'daily';

export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: number;
  retryAfterSeconds?: number;
}

const RATE_LIMITS: Record<RateLimitAction, { limit: number; window: RateLimitWindow }> = {
  upload: { limit: 5, window: 'hourly' },
  comment: { limit: 20, window: 'hourly' },
  like: { limit: 100, window: 'hourly' },
  follow: { limit: 30, window: 'hourly' },
  share: { limit: 50, window: 'hourly' },
  flag: { limit: 10, window: 'daily' },
};

function generateBucket(window: RateLimitWindow): string {
  const now = new Date();
  if (window === 'hourly') {
    const year = now.getUTCFullYear();
    const month = String(now.getUTCMonth() + 1).padStart(2, '0');
    const day = String(now.getUTCDate()).padStart(2, '0');
    const hour = String(now.getUTCHours()).padStart(2, '0');
    return `${year}-${month}-${day}-${hour}`;
  } else {
    return now.toISOString().split('T')[0];
  }
}

function getResetTimestamp(window: RateLimitWindow): number {
  const now = Date.now();
  if (window === 'hourly') {
    const nextHour = new Date(now);
    nextHour.setUTCHours(nextHour.getUTCHours() + 1, 0, 0, 0);
    return nextHour.getTime();
  } else {
    const nextDay = new Date(now);
    nextDay.setUTCDate(nextDay.getUTCDate() + 1);
    nextDay.setUTCHours(0, 0, 0, 0);
    return nextDay.getTime();
  }
}

export async function checkRateLimit(
  userId: string,
  action: RateLimitAction
): Promise<RateLimitResult> {
  const config = RATE_LIMITS[action];
  const db = getDb();
  const docRef = db.collection('rate_limits').doc(userId);
  const currentBucket = generateBucket(config.window);
  const resetAt = getResetTimestamp(config.window);

  try {
    return await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(docRef);
      const data = doc.data();
      const actionData = data?.[action] || { count: 0, bucket: currentBucket, resetAt };

      if (actionData.bucket !== currentBucket) {
        actionData.count = 0;
        actionData.bucket = currentBucket;
        actionData.resetAt = resetAt;
      }

      if (actionData.count >= config.limit) {
        const retryAfter = Math.ceil((resetAt - Date.now()) / 1000);
        return {
          allowed: false,
          remaining: 0,
          resetAt,
          retryAfterSeconds: retryAfter,
        };
      }

      actionData.count += 1;
      const ttl = Date.now() + 30 * 24 * 60 * 60 * 1000;

      transaction.set(
        docRef,
        {
          userId,
          [action]: actionData,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          ttl: admin.firestore.Timestamp.fromMillis(ttl),
        },
        { merge: true }
      );

      return {
        allowed: true,
        remaining: config.limit - actionData.count,
        resetAt: actionData.resetAt,
      };
    });
  } catch (error) {
    logger.error('Rate limit check failed', { userId, action, error });
    return {
      allowed: true,
      remaining: config.limit,
      resetAt,
    };
  }
}
