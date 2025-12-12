import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';

// Enhanced health check runs every 15 minutes and stores additional metrics
export const systemHealthCheck = onSchedule({ schedule: '*/15 * * * *', timeZone: 'UTC' }, async () => {
  if (!admin.apps.length) admin.initializeApp();
  const db = admin.firestore();
  const now = Date.now();
  const oneHourAgo = new Date(now - 60 * 60 * 1000);

  const snap = await db
    .collection('videos')
    .where('updatedAt', '>=', admin.firestore.Timestamp.fromDate(oneHourAgo))
    .get();

  let ready = 0;
  let failed = 0;
  let processing = 0;
  for (const doc of snap.docs) {
    const s = (doc.data().status as string) || '';
    if (s === 'ready') ready++;
    else if (s === 'failed') failed++;
    else if (s === 'processing') processing++;
  }
  const total = ready + failed + processing;
  const successRate = total > 0 ? ready / total : 1;

  // Optional: approximate counts from Storage (can be expensive; limit results)
  let storageRawFilesCount: number | null = null;
  try {
    const bucket = admin.storage().bucket();
    const [files] = await bucket.getFiles({ prefix: 'raw-videos/', maxResults: 1000 });
    storageRawFilesCount = files.length;
  } catch {
    storageRawFilesCount = null;
  }

  await db.collection('analytics').add({
    type: 'system_health',
    period: 'quarter-hour',
    metrics: {
      processingSuccessRate: successRate,
      processingErrors: failed,
      processingInFlight: processing,
      videosUpdatedLastHour: total,
      storageRawFilesCount,
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // API metrics are aggregated independently by aggregateAPIMetricsHourly.
});
