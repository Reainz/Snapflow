import { NextResponse } from 'next/server';
import { getAdminAuth, getAdminFirestore } from '@/lib/firebase/admin';

export const runtime = 'nodejs';

export async function GET(request: Request) {
  // Verify admin token
  const token = request.headers.get('authorization')?.replace(/^[Bb]earer\s+/, '');
  if (!token) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    const auth = getAdminAuth();
    const decoded = await auth.verifyIdToken(token);
    if (decoded.admin !== true) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
    }

    const db = getAdminFirestore();
    const now = new Date();

    // Get counts using Admin SDK (bypasses security rules)
    const [usersSnap, videosSnap] = await Promise.all([
      db.collection('users').count().get(),
      db.collection('videos').count().get(),
    ]);

    const totalUsers = usersSnap.data().count;
    const totalVideos = videosSnap.data().count;

    // Get active users from analytics or calculate
    const { dauCurrent, wauCurrent, mauCurrent, dauPrev, wauPrev, mauPrev } = 
      await getActiveUserMetrics(db, now);

    return NextResponse.json({
      totalUsers,
      totalVideos,
      dailyActiveUsers: dauCurrent,
      weeklyActiveUsers: wauCurrent,
      monthlyActiveUsers: mauCurrent,
      dauTrend: calculateTrend(dauPrev, dauCurrent),
      wauTrend: calculateTrend(wauPrev, wauCurrent),
      mauTrend: calculateTrend(mauPrev, mauCurrent),
    });
  } catch (error: any) {
    console.error('Stats API error:', error?.message || error);
    return NextResponse.json({ error: 'Failed to load stats' }, { status: 500 });
  }
}

async function getActiveUserMetrics(db: FirebaseFirestore.Firestore, now: Date) {
  // Try to get from analytics collection first
  try {
    const metricsSnap = await db.collection('analytics')
      .where('type', '==', 'user_metrics')
      .orderBy('createdAt', 'desc')
      .limit(2)
      .get();

    if (!metricsSnap.empty) {
      const [latest, previous] = metricsSnap.docs;
      const latestData = latest?.data()?.metrics || {};
      const prevData = previous?.data()?.metrics || {};

      return {
        dauCurrent: latestData.dau ?? 0,
        wauCurrent: latestData.wau ?? 0,
        mauCurrent: latestData.mau ?? 0,
        dauPrev: prevData.dau ?? 0,
        wauPrev: prevData.wau ?? 0,
        mauPrev: prevData.mau ?? 0,
      };
    }
  } catch (e) {
    console.warn('Could not fetch analytics metrics, using defaults');
  }

  // Fallback to simple counts based on lastActiveAt field
  const dayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
  const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  const monthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

  const [dauSnap, wauSnap, mauSnap] = await Promise.all([
    db.collection('users').where('lastActiveAt', '>=', dayAgo).count().get(),
    db.collection('users').where('lastActiveAt', '>=', weekAgo).count().get(),
    db.collection('users').where('lastActiveAt', '>=', monthAgo).count().get(),
  ]);

  return {
    dauCurrent: dauSnap.data().count,
    wauCurrent: wauSnap.data().count,
    mauCurrent: mauSnap.data().count,
    dauPrev: 0,
    wauPrev: 0,
    mauPrev: 0,
  };
}

function calculateTrend(previous: number, current: number): number {
  if (previous === 0) return current > 0 ? 100 : 0;
  return Math.round(((current - previous) / previous) * 100);
}
