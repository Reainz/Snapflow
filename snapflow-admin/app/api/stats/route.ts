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
  // Real-time counts (do not rely on scheduled analytics which can be stale during the day).
  const dayMs = 24 * 60 * 60 * 1000;
  const dayAgo = new Date(now.getTime() - dayMs);
  const weekAgo = new Date(now.getTime() - 7 * dayMs);
  const monthAgo = new Date(now.getTime() - 30 * dayMs);

  const prevDayStart = new Date(now.getTime() - 2 * dayMs);
  const prevDayEnd = dayAgo;
  const prevWeekStart = new Date(now.getTime() - 14 * dayMs);
  const prevWeekEnd = weekAgo;
  const prevMonthStart = new Date(now.getTime() - 60 * dayMs);
  const prevMonthEnd = monthAgo;

  const countActive = async (start: Date, end: Date): Promise<number> => {
    const [lastActiveSnap, updatedSnap] = await Promise.all([
      db
        .collection('users')
        .where('lastActiveAt', '>=', start)
        .where('lastActiveAt', '<=', end)
        .count()
        .get(),
      db
        .collection('users')
        .where('updatedAt', '>=', start)
        .where('updatedAt', '<=', end)
        .count()
        .get(),
    ]);

    const lastActiveCount = lastActiveSnap.data().count;
    const updatedCount = updatedSnap.data().count;
    return Math.max(lastActiveCount, updatedCount);
  };

  const [dauCurrent, wauCurrent, mauCurrent, dauPrev, wauPrev, mauPrev] = await Promise.all([
    countActive(dayAgo, now),
    countActive(weekAgo, now),
    countActive(monthAgo, now),
    countActive(prevDayStart, prevDayEnd),
    countActive(prevWeekStart, prevWeekEnd),
    countActive(prevMonthStart, prevMonthEnd),
  ]);

  return { dauCurrent, wauCurrent, mauCurrent, dauPrev, wauPrev, mauPrev };
}

function calculateTrend(previous: number, current: number): number {
  if (previous === 0) return current > 0 ? 100 : 0;
  return Math.round(((current - previous) / previous) * 100);
}
