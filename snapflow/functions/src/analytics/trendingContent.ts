import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';

export const calculateTrendingVideos = onSchedule({ schedule: '*/30 * * * *', timeZone: 'UTC' }, async () => {
  if (!admin.apps.length) admin.initializeApp();
  const db = admin.firestore();
  const now = new Date();
  const dayMs = 24 * 60 * 60 * 1000;

  // Consider last 7 days
  const since = new Date(now.getTime() - 7 * dayMs);
  const videosSnap = await db
    .collection('videos')
    .where('status', '==', 'ready')
    .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(since))
    .limit(500)
    .get();

  const scored = videosSnap.docs.map((d) => {
    const v = d.data() as any;
    const createdAt = (v.createdAt as admin.firestore.Timestamp | undefined)?.toDate() || since;
    const hoursSince = Math.max(1, (now.getTime() - createdAt.getTime()) / (60 * 60 * 1000));
    const likes = v.likesCount || 0;
    const comments = v.commentsCount || 0;
    const shares = v.sharesCount || 0;
    const base = likes + 2 * comments + 3 * shares;
    const decay = 1 / Math.pow(hoursSince, 0.5); // mild decay
    const score = base * decay;
    return { id: d.id, score };
  });

  scored.sort((a, b) => b.score - a.score);
  const top50 = scored.slice(0, 50);

  const batch = db.batch();
  // Clear existing trending_videos collection (truncate by deleting first 100 docs)
  const existing = await db.collection('trending_videos').limit(100).get();
  existing.docs.forEach((doc) => batch.delete(doc.ref));
  top50.forEach((t, idx) => {
    const ref = db.collection('trending_videos').doc();
    batch.set(ref, {
      videoId: t.id,
      score: t.score,
      rank: idx + 1,
      calculatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  await batch.commit();
});
