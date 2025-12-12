import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';

// Callable function used by the mobile client to create the initial
// "video draft" document. This bypasses Firestore security rules by
// using the Admin SDK, while still enforcing that the caller is the
// owner of the video.
export const createVideoDraft = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const uid = request.auth.uid;
  const { videoId, data } = request.data as {
    videoId?: string;
    data?: Record<string, unknown>;
  };

  if (!videoId || typeof videoId !== 'string') {
    throw new HttpsError('invalid-argument', 'videoId is required and must be a string.');
  }

  if (!data || typeof data !== 'object') {
    throw new HttpsError('invalid-argument', 'data payload is required.');
  }

  // Enforce ownership on the server side.
  if (data['ownerId'] !== uid) {
    throw new HttpsError('permission-denied', 'Caller must be the owner of the video.');
  }

  if (!admin.apps.length) {
    admin.initializeApp();
  }
  const db = admin.firestore();

  const now = admin.firestore.FieldValue.serverTimestamp();

  const payload: Record<string, unknown> = {
    ...data,
    ownerId: uid,
    createdAt: now,
    updatedAt: now,
  };

  await db.collection('videos').doc(videoId).set(payload, { merge: false });

  return { success: true };
});

