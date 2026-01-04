import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';

function startOfDay(d: Date) {
  return new Date(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
}

async function getActiveUsersCount(
  db: admin.firestore.Firestore,
  start: Date,
  end: Date,
  field: 'lastActiveAt' | 'updatedAt'
): Promise<number> {
  try {
    const snap = await db
      .collection('users')
      .where(field, '>=', admin.firestore.Timestamp.fromDate(start))
      .where(field, '<=', admin.firestore.Timestamp.fromDate(end))
      .count()
      .get();
    return (snap.data().count as number) || 0;
  } catch (error) {
    console.warn(`Field ${field} not available for active user count; falling back.`, error);
    return 0;
  }
}

export const aggregateUserAnalytics = onSchedule({ schedule: '0 2 * * *', timeZone: 'UTC' }, async () => {
  if (!admin.apps.length) admin.initializeApp();
  const db = admin.firestore();
  const now = new Date();
  const today = startOfDay(now);
  const dayMs = 24 * 60 * 60 * 1000;

  // DAU: prefer lastActiveAt, fallback to updatedAt (legacy)
  const dauStart = new Date(now.getTime() - dayMs);
  const dau = Math.max(
    await getActiveUsersCount(db, dauStart, now, 'lastActiveAt'),
    await getActiveUsersCount(db, dauStart, now, 'updatedAt')
  );

  // WAU: last 7d
  const wauStart = new Date(now.getTime() - 7 * dayMs);
  const wau = Math.max(
    await getActiveUsersCount(db, wauStart, now, 'lastActiveAt'),
    await getActiveUsersCount(db, wauStart, now, 'updatedAt')
  );

  // MAU: last 30d
  const mauStart = new Date(now.getTime() - 30 * dayMs);
  const mau = Math.max(
    await getActiveUsersCount(db, mauStart, now, 'lastActiveAt'),
    await getActiveUsersCount(db, mauStart, now, 'updatedAt')
  );

  // Retention (naive, based on createdAt and activity windows)
  // Day 1 retention: users created yesterday and active today
  // Prefer lastLoginAt, fallback to updatedAt
  const createdYesterdayStart = new Date(startOfDay(new Date(now.getTime() - dayMs)).getTime());
  const createdYesterdayEnd = new Date(createdYesterdayStart.getTime() + dayMs - 1);
  const newUsersSnap = await db
    .collection('users')
    .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(createdYesterdayStart))
    .where('createdAt', '<=', admin.firestore.Timestamp.fromDate(createdYesterdayEnd))
    .get();
  const newUsers = newUsersSnap.docs.map((d) => d.id);
  let d1Retained = 0;
  if (newUsers.length) {
    // Try lastActiveAt first, fallback to updatedAt
    try {
      const todayActiveSnap = await db
        .collection('users')
        .where(admin.firestore.FieldPath.documentId(), 'in', newUsers.slice(0, 10)) // chunk if needed
        .where('lastActiveAt', '>=', admin.firestore.Timestamp.fromDate(dauStart))
        .get();
      d1Retained += todayActiveSnap.size;
    } catch (error) {
      // lastActiveAt not available, fallback to updatedAt
      console.warn('lastActiveAt not available for retention calculation; falling back to updatedAt.', error);
      const todayActiveSnap = await db
        .collection('users')
        .where(admin.firestore.FieldPath.documentId(), 'in', newUsers.slice(0, 10)) // chunk if needed
        .where('updatedAt', '>=', admin.firestore.Timestamp.fromDate(dauStart))
        .get();
      d1Retained += todayActiveSnap.size;
    }
    // Note: For >10 new users, additional chunks should be processed. Keeping simple for MVP.
  }
  const d1RetentionRate = newUsers.length > 0 ? d1Retained / newUsers.length : 0;

  // Geographic distribution aggregation
  const usersWithCountrySnap = await db
    .collection('users')
    .where('countryCode', '!=', null)
    .get();
  
  const countryMap = new Map<string, number>();
  const regionMap = new Map<string, number>();
  
  usersWithCountrySnap.docs.forEach((doc) => {
    const data = doc.data();
    const countryCode = data.countryCode as string | undefined;
    const region = data.region as string | undefined;
    
    if (countryCode) {
      countryMap.set(countryCode, (countryMap.get(countryCode) || 0) + 1);
    }
    if (region) {
      regionMap.set(region, (regionMap.get(region) || 0) + 1);
    }
  });
  
  const countries = Array.from(countryMap.entries()).map(([countryCode, count]) => ({
    countryCode,
    count,
  })).sort((a, b) => b.count - a.count); // Sort by count descending
  
  const regions = Array.from(regionMap.entries()).map(([region, count]) => ({
    region,
    count,
  })).sort((a, b) => b.count - a.count);

  await db.collection('analytics').add({
    type: 'user_metrics',
    period: 'daily',
    metrics: {
      dau,
      wau,
      mau,
      d1RetentionRate,
      newUsers: newUsers.length,
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    date: admin.firestore.Timestamp.fromDate(today),
  });

  // Store geographic distribution separately for better querying
  await db.collection('analytics').add({
    type: 'geographic_distribution',
    period: 'daily',
    metrics: {
      countries,
      regions,
      totalUsersWithGeoData: usersWithCountrySnap.size,
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    date: admin.firestore.Timestamp.fromDate(today),
  });
});
