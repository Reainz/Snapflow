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

  const ref = db.collection('videos').doc(videoId);

  await db.runTransaction(async (tx) => {
    const existing = await tx.get(ref);
    const existingData = existing.exists ? (existing.data() as Record<string, any>) : null;

    // Prevent a late draft write from clobbering processed fields (race with processVideoUpload).
    // If the server-side pipeline already finished (status=ready or processed fields exist),
    // do not allow the draft payload to downgrade status back to "processing".
    const alreadyProcessed =
      (existingData?.status as string | undefined) === 'ready' ||
      !!existingData?.hlsUrl ||
      !!existingData?.processedAt;

    const payload: Record<string, unknown> = {
      ...data,
      ownerId: uid,
      updatedAt: now,
    };

    // Persist the bucket name to make retries resilient when FIREBASE_CONFIG is missing storageBucket.
    const rawVideoUrl = (data['rawVideoUrl'] as string | undefined) ?? '';
    const bucketMatch = rawVideoUrl.match(/https?:\/\/firebasestorage\.googleapis\.com\/v0\/b\/([^/]+)\/o\//i);
    if (bucketMatch && bucketMatch[1]) {
      payload.rawVideoBucket = bucketMatch[1];
    }

    // Only set createdAt when missing (processing-created docs might not have it yet).
    if (!existingData?.createdAt) {
      payload.createdAt = now;
    }

    if (alreadyProcessed) {
      delete payload.status;
    }

    // Always merge to preserve any fields written by Cloud Functions (hlsUrl, processedAt, etc).
    tx.set(ref, payload, { merge: true });
  });

  return { success: true };
});
