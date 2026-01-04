import * as admin from 'firebase-admin';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions';
import { NotificationDocument } from './types';
import { withPerformanceMonitoring } from '../utils/performance-monitoring';

if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Sends an FCM push notification when a new notification doc is created under users/{userId}/notifications/{id}
 */
export const sendPushNotification = onDocumentCreated(
  'users/{userId}/notifications/{notificationId}',
  async (event) => {
    await withPerformanceMonitoring(async () => {
      try {
        const userId = event.params.userId as string;
        const snap = event.data;
        if (!snap) return;
        const data = snap.data() as NotificationDocument | undefined;
        if (!data) return;

      // Fetch recipient's FCM token from users/{userId}.fcmToken
      const db = admin.firestore();
      const userDoc = await db.collection('users').doc(userId).get();
      const user = userDoc.data() as any | undefined;
      const fcmToken: string | undefined = user?.fcmToken;
      if (!fcmToken) {
        logger.debug(`No fcmToken for user ${userId}, skipping push.`);
        return;
      }

      const title = data.title || defaultTitle(data.type);
      const body = data.body || defaultBody(data.type);

      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title,
          body,
        },
        data: {
          type: data.type,
          actorUserId: data.actorUserId,
          videoId: data.videoId ?? '',
          commentId: data.commentId ?? '',
          route: (data.payload as any)?.route ?? '',
        },
      });
    } catch (e) {
      logger.error('sendPushNotification failed', e as any);
    }
    }, 'sendPushNotification')();
  }
);

function defaultTitle(type: string): string {
  switch (type) {
    case 'like':
      return 'New Like';
    case 'comment':
      return 'New Comment';
    case 'follow':
      return 'New Follower';
    case 'share':
      return 'Video Shared';
    case 'video':
      return 'Video update';
    default:
      return 'Notification';
  }
}

function defaultBody(type: string): string {
  switch (type) {
    case 'like':
      return 'Someone liked your video.';
    case 'comment':
      return 'Someone commented on your video.';
    case 'follow':
      return 'You have a new follower.';
    case 'share':
      return 'Your video was shared.';
    case 'video':
      return 'Your video status was updated.';
    default:
      return 'You have a new notification.';
  }
}
