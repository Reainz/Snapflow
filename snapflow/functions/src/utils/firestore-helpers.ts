import * as admin from 'firebase-admin';

export function getDb() {
  if (!admin.apps.length) {
    admin.initializeApp();
  }
  return admin.firestore();
}

export async function updateVideoStatus(
  videoId: string,
  data: Partial<{
    status: 'processing' | 'ready' | 'failed';
    hlsUrl: string | null;
    thumbnailUrl: string | null;
    durationSeconds: number | null;
    processedAt:
      | admin.firestore.FieldValue
      | FirebaseFirestore.Timestamp
      | null;
    error: string | null;
    errorCode: string | null;
    lastErrorAt:
      | admin.firestore.FieldValue
      | FirebaseFirestore.Timestamp
      | null;
    processingDurationMs: number | null;
    cloudinaryPublicId: string | null;
  }>
) {
  const db = getDb();
  const ref = db.collection('videos').doc(videoId);
  const now = admin.firestore.FieldValue.serverTimestamp();
  await ref.set({ ...data, updatedAt: now }, { merge: true });
}
