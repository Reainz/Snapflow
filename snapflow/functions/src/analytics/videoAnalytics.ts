import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';

export const aggregateVideoAnalytics = onSchedule({ schedule: '0 3 * * *', timeZone: 'UTC' }, async () => {
  if (!admin.apps.length) admin.initializeApp();
  const db = admin.firestore();
  const now = new Date();
  const dayMs = 24 * 60 * 60 * 1000;
  const dayStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  const prevDayStart = new Date(dayStart.getTime() - dayMs);

  // Daily uploads count
  const dailySnap = await db
    .collection('videos')
    .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(prevDayStart))
    .where('createdAt', '<', admin.firestore.Timestamp.fromDate(dayStart))
    .count()
    .get();
  const dailyUploads = (dailySnap.data().count as number) || 0;

  // Top videos by engagement (likes + 2*comments) in last 7 days
  const weekStart = new Date(now.getTime() - 7 * dayMs);
  const weekVideos = await db
    .collection('videos')
    .where('status', '==', 'ready')
    .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(weekStart))
    .limit(200)
    .get();
  const top = weekVideos.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .map((v: any) => ({ id: v.id, score: (v.likesCount || 0) + 2 * (v.commentsCount || 0), likes: v.likesCount || 0, comments: v.commentsCount || 0 }))
    .sort((a, b) => b.score - a.score)
    .slice(0, 20);

  // Average watch time metrics from video_watch_events collection
  const watchEventsSnap = await db
    .collection('video_watch_events')
    .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(prevDayStart))
    .where('createdAt', '<', admin.firestore.Timestamp.fromDate(dayStart))
    .get();

  let totalWatchTimeSeconds = 0;
  let totalWatchEvents = 0;
  let completedWatches = 0;
  const watchTimeByVideo = new Map<string, { totalWatchTime: number; count: number }>();

  watchEventsSnap.docs.forEach((doc) => {
    const data = doc.data();
    const videoId = data.videoId as string;
    const watchDurationSeconds = data.watchDurationSeconds as number;
    const completed = data.completed as boolean;

    totalWatchTimeSeconds += watchDurationSeconds;
    totalWatchEvents++;
    if (completed) completedWatches++;

    // Aggregate by video
    const videoStats = watchTimeByVideo.get(videoId) || { totalWatchTime: 0, count: 0 };
    videoStats.totalWatchTime += watchDurationSeconds;
    videoStats.count++;
    watchTimeByVideo.set(videoId, videoStats);
  });

  const averageWatchTimeSeconds = totalWatchEvents > 0 ? totalWatchTimeSeconds / totalWatchEvents : 0;
  const completionRate = totalWatchEvents > 0 ? completedWatches / totalWatchEvents : 0;

  // Calculate average watch time per video (top 20)
  const averageWatchTimePerVideo = Array.from(watchTimeByVideo.entries())
    .map(([videoId, stats]) => ({
      videoId,
      avgWatchTime: stats.totalWatchTime / stats.count,
      totalViews: stats.count,
    }))
    .sort((a, b) => b.totalViews - a.totalViews)
    .slice(0, 20);

  await db.collection('analytics').add({
    type: 'video_metrics',
    period: 'daily',
    metrics: {
      dailyUploads,
      topVideos: top,
      averageWatchTimeSeconds: Math.round(averageWatchTimeSeconds * 100) / 100,
      averageWatchTimePerVideo,
      completionRate: Math.round(completionRate * 100) / 100,
      totalWatchEvents,
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
});
