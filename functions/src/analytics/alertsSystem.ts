import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';

export const checkSystemAlerts = onSchedule({ schedule: '*/15 * * * *', timeZone: 'UTC' }, async () => {
  if (!admin.apps.length) admin.initializeApp();
  const db = admin.firestore();
  const now = Date.now();
  const oneHourAgo = new Date(now - 60 * 60 * 1000);

  const videosSnap = await db
    .collection('videos')
    .where('updatedAt', '>=', admin.firestore.Timestamp.fromDate(oneHourAgo))
    .get();

  let ready = 0;
  let failed = 0;
  for (const doc of videosSnap.docs) {
    const s = (doc.data().status as string) || '';
    if (s === 'ready') ready++;
    else if (s === 'failed') failed++;
  }
  const total = ready + failed;
  const failureRate = total > 0 ? failed / total : 0;

  // Storage usage approximation
  let storageRawFilesCount: number | null = null;
  try {
    const bucket = admin.storage().bucket();
    const [files] = await bucket.getFiles({ prefix: 'raw-videos/', maxResults: 2000 });
    storageRawFilesCount = files.length;
  } catch {
    storageRawFilesCount = null;
  }

  const alerts: Array<{ type: string; severity: string; message: string; threshold: number; currentValue: number }> = [];

  if (failureRate > 0.1) {
    alerts.push({
      type: 'processing_failure',
      severity: 'critical',
      message: `Processing failure rate ${Math.round(failureRate * 100)}% exceeds 10%`,
      threshold: 0.1,
      currentValue: failureRate,
    });
  }

  if ((storageRawFilesCount ?? 0) > 10000) {
    alerts.push({
      type: 'storage_warning',
      severity: 'warning',
      message: `Raw videos objects count ${(storageRawFilesCount ?? 0)} exceeds 10k (approx)`,
      threshold: 10000,
      currentValue: storageRawFilesCount ?? 0,
    });
  }

  const batch = db.batch();
  for (const a of alerts) {
    const ref = db.collection('admin_alerts').doc();
    batch.set(ref, {
      ...a,
      acknowledged: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  if (alerts.length) await batch.commit();
});
