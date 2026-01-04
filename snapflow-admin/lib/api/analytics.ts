import { collection, query, where, orderBy, limit, getDocs, Timestamp } from 'firebase/firestore';
import { db, auth } from '@/lib/firebase/config';

// Helper function to call server-side analytics API
async function fetchAnalyticsFromServer(type: string): Promise<any> {
  const user = auth.currentUser;
  if (!user) {
    throw new Error('Not authenticated');
  }
  
  const token = await user.getIdToken();
  
  const response = await fetch(`/api/analytics?type=${type}`, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({ error: 'Unknown error' }));
    throw new Error(error.error || `Failed to load ${type}`);
  }

  return response.json();
}

// Types
export interface UserGrowthData {
  date: string;
  count: number;
}

export interface VideoUploadData {
  date: string;
  count: number;
}

export interface RetentionMetrics {
  d1RetentionRate: number;
  newUsersYesterday: number;
  isComputed?: boolean;
}

export interface SystemHealthMetrics {
  processingSuccessRate: number;
  processingErrors: number;
  processingInFlight: number;
  storageRawFilesCount?: number;
  alertsLastHour?: number;
  windowMinutes?: number;
  dataSource?: 'analytics' | 'alerts' | 'fallback';
  hasData?: boolean;
  message?: string;
  isComputed?: boolean;
  cloudinaryJobs?: {
    activeJobs: number;
    failedJobs: number;
    lastChecked: Date | null;
  };
  cloudFunctionsHealth?: {
    healthy: boolean;
    recentErrors: number;
    lastChecked: Date | null;
  };
}

export interface WatchTimeMetrics {
  averageWatchTimeSeconds: number;
  completionRate: number;
  totalWatchEvents: number;
  averageWatchTimePerVideo: Array<{
    videoId: string;
    avgWatchTime: number;
    totalViews: number;
  }>;
  lastUpdated: Date | null;
  isComputed?: boolean;
  hasData?: boolean;
}

export interface CountryData {
  countryCode: string;
  count: number;
}

export interface RegionData {
  region: string;
  count: number;
}

export interface GeographicDistribution {
  countries: CountryData[];
  regions: RegionData[];
  totalUsersWithGeoData: number;
  lastUpdated: Date | null;
  isComputed?: boolean;
}

export interface CDNMetrics {
  bandwidthGB: number;
  downloadRequests: number;
  averageResponseTimeMs: number;
  peakBandwidthGB: number;
  peakBandwidthTime: Date | null;
  metricsCollectedAt: Date | null;
  lastUpdated: Date | null;
  isComputed?: boolean;
  hasData?: boolean;
  providers?: {
    firebase_storage?: {
      bandwidthBytes?: number;
      bandwidthGB?: number;
      downloadRequests?: number;
      averageResponseTimeMs?: number;
      peakBandwidthGB?: number;
      peakBandwidthTime?: Date | null;
      metricsCollectedAt?: Date | null;
      dataSource?: string;
    };
    cloudinary?: {
      bandwidthBytes?: number | null;
      bandwidthGB?: number | null;
      bandwidthLimitBytes?: number | null;
      bandwidthLimitGB?: number | null;
      downloadRequests?: number | null;
      averageResponseTimeMs?: number | null;
      peakBandwidthGB?: number | null;
      peakBandwidthTime?: Date | null;
      metricsCollectedAt?: Date | null;
      dataSource?: string;
    };
  };
}

export interface APIFunctionMetric {
  name: string;
  avgResponseTimeMs: number;
  errorRate: number;
  totalCalls: number;
  p95ResponseTimeMs: number;
  errors: number;
}

export interface APIMetrics {
  functions: APIFunctionMetric[];
  overallAvgResponseTime: number;
  overallErrorRate: number;
  totalCalls: number;
  totalErrors: number;
  lastUpdated: Date | null;
  isComputed?: boolean;
  hasData?: boolean;
}

export interface TrendingVideo {
  id: string;
  title: string;
  ownerId: string;
  ownerUsername?: string;
  thumbnailUrl?: string;
  viewsCount: number;
  likesCount: number;
  commentsCount: number;
  sharesCount: number;
  engagementScore?: number;
  createdAt: any;
}

// Get user growth data grouped by date
export async function getUserGrowthData(start: Date, end: Date): Promise<UserGrowthData[]> {
  const q = query(
    collection(db, 'users'),
    where('createdAt', '>=', Timestamp.fromDate(start)),
    where('createdAt', '<=', Timestamp.fromDate(end)),
    orderBy('createdAt', 'asc')
  );
  
  const snapshot = await getDocs(q);
  
  // Group users by date
  const dateMap: Map<string, number> = new Map();
  
  snapshot.forEach(doc => {
    const createdAt = doc.data().createdAt?.toDate();
    if (createdAt) {
      const dateKey = createdAt.toISOString().split('T')[0]; // YYYY-MM-DD
      dateMap.set(dateKey, (dateMap.get(dateKey) || 0) + 1);
    }
  });
  
  // Convert to array and sort
  const result: UserGrowthData[] = [];
  dateMap.forEach((count, date) => {
    result.push({ date, count });
  });

  // Ensure missing dates are present (0) so charts don't render misleading flat lines.
  const startUTC = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth(), start.getUTCDate()));
  const endUTC = new Date(Date.UTC(end.getUTCFullYear(), end.getUTCMonth(), end.getUTCDate()));
  const filled: UserGrowthData[] = [];
  for (let d = startUTC; d.getTime() <= endUTC.getTime(); d = new Date(d.getTime() + 24 * 60 * 60 * 1000)) {
    const dateKey = d.toISOString().split('T')[0];
    filled.push({ date: dateKey, count: dateMap.get(dateKey) || 0 });
  }
  
  return filled.sort((a, b) => a.date.localeCompare(b.date));
}

// Get video upload data grouped by date
export async function getVideoUploadData(start: Date, end: Date): Promise<VideoUploadData[]> {
  const q = query(
    collection(db, 'videos'),
    where('createdAt', '>=', Timestamp.fromDate(start)),
    where('createdAt', '<=', Timestamp.fromDate(end)),
    orderBy('createdAt', 'asc')
  );
  
  const snapshot = await getDocs(q);
  
  // Group videos by date
  const dateMap: Map<string, number> = new Map();
  
  snapshot.forEach(doc => {
    const createdAt = doc.data().createdAt?.toDate();
    if (createdAt) {
      const dateKey = createdAt.toISOString().split('T')[0]; // YYYY-MM-DD
      dateMap.set(dateKey, (dateMap.get(dateKey) || 0) + 1);
    }
  });
  
  // Convert to array and sort
  const result: VideoUploadData[] = [];
  dateMap.forEach((count, date) => {
    result.push({ date, count });
  });

  const startUTC = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth(), start.getUTCDate()));
  const endUTC = new Date(Date.UTC(end.getUTCFullYear(), end.getUTCMonth(), end.getUTCDate()));
  const filled: VideoUploadData[] = [];
  for (let d = startUTC; d.getTime() <= endUTC.getTime(); d = new Date(d.getTime() + 24 * 60 * 60 * 1000)) {
    const dateKey = d.toISOString().split('T')[0];
    filled.push({ date: dateKey, count: dateMap.get(dateKey) || 0 });
  }
  
  return filled.sort((a, b) => a.date.localeCompare(b.date));
}

// Get retention metrics from analytics collection
export async function getRetentionMetrics(): Promise<RetentionMetrics | null> {
  const q = query(
    collection(db, 'analytics'),
    where('type', '==', 'user_metrics'),
    orderBy('createdAt', 'desc'),
    limit(1)
  );
  
  const snapshot = await getDocs(q);
  
  if (snapshot.empty) {
    return computeRetentionMetricsFallback();
  }
  
  const data = snapshot.docs[0].data();
  const metrics = data.metrics || {};
  
  return {
    d1RetentionRate: metrics.d1RetentionRate || 0,
    newUsersYesterday: metrics.newUsers || 0,
    isComputed: false,
  };
}

// Get system health metrics from analytics collection
export async function getSystemHealth(): Promise<SystemHealthMetrics | null> {
  const q = query(
    collection(db, 'analytics'),
    where('type', '==', 'system_health'),
    orderBy('createdAt', 'desc'),
    limit(1)
  );
  
  const snapshot = await getDocs(q);
  
  if (snapshot.empty) {
    return computeSystemHealthFallback();
  }
  
  const data = snapshot.docs[0].data();
  const metrics = data.metrics || {};

  // Backend may store success rate as a fraction (0..1) or a percentage (0..100).
  // Normalize to percentage for the UI.
  const rawRate = typeof metrics.processingSuccessRate === 'number' ? metrics.processingSuccessRate : 0;
  const processingSuccessRate =
    rawRate <= 1 ? rawRate * 100 : rawRate;
  
  return {
    processingSuccessRate,
    processingErrors: metrics.processingErrors || 0,
    processingInFlight: metrics.processingInFlight || 0,
    storageRawFilesCount: metrics.storageRawFilesCount,
    windowMinutes: 60,
    dataSource: 'analytics',
    hasData: true,
    isComputed: false,
  };
}

// Get watch time metrics from analytics collection
export async function getWatchTimeMetrics(): Promise<WatchTimeMetrics | null> {
  const q = query(
    collection(db, 'analytics'),
    where('type', '==', 'video_metrics'),
    orderBy('createdAt', 'desc'),
    limit(1)
  );
  
  const snapshot = await getDocs(q);
  
  if (snapshot.empty) {
    return computeWatchTimeFallback();
  }
  
  const data = snapshot.docs[0].data();
  const metrics = data.metrics || {};
  const createdAt = data.createdAt?.toDate() || null;
  
  return {
    averageWatchTimeSeconds: metrics.averageWatchTimeSeconds || 0,
    completionRate: metrics.completionRate || 0,
    totalWatchEvents: metrics.totalWatchEvents || 0,
    averageWatchTimePerVideo: metrics.averageWatchTimePerVideo || [],
    lastUpdated: createdAt,
    isComputed: false,
    hasData: true,
  };
}

// Get geographic distribution from analytics collection
export async function getGeographicDistribution(): Promise<GeographicDistribution | null> {
  const q = query(
    collection(db, 'analytics'),
    where('type', '==', 'geographic_distribution'),
    orderBy('createdAt', 'desc'),
    limit(1)
  );
  
  const snapshot = await getDocs(q);
  
  if (snapshot.empty) {
    return computeGeographicDistributionFallback();
  }
  
  const data = snapshot.docs[0].data();
  const metrics = data.metrics || {};
  const createdAt = data.createdAt?.toDate() || null;
  
  return {
    countries: metrics.countries || [],
    regions: metrics.regions || [],
    totalUsersWithGeoData: metrics.totalUsersWithGeoData || 0,
    lastUpdated: createdAt,
    isComputed: false,
  };
}

// Get CDN metrics from analytics collection (via server-side API)
export async function getCDNMetrics(): Promise<CDNMetrics | null> {
  try {
    const data = await fetchAnalyticsFromServer('cdn_metrics');
    
    if (!data) {
      return computeCDNMetricsFallback();
    }
    
    return {
      bandwidthGB: data.bandwidthGB || 0,
      downloadRequests: data.downloadRequests || 0,
      averageResponseTimeMs: data.averageResponseTimeMs || 0,
      peakBandwidthGB: data.peakBandwidthGB || 0,
      peakBandwidthTime: data.peakBandwidthTime ? new Date(data.peakBandwidthTime) : null,
      metricsCollectedAt: data.metricsCollectedAt ? new Date(data.metricsCollectedAt) : null,
      lastUpdated: data.lastUpdated ? new Date(data.lastUpdated) : null,
      isComputed: data.isComputed || false,
      hasData: data.hasData || false,
      providers: data.providers,
    };
  } catch (error) {
    console.error('Error fetching CDN metrics:', error);
    return computeCDNMetricsFallback();
  }
}

// Get API metrics from analytics collection (via server-side API)
export async function getAPIMetrics(): Promise<APIMetrics | null> {
  try {
    const data = await fetchAnalyticsFromServer('api_metrics');
    
    if (!data) {
      return computeAPIMetricsFallback();
    }
    
    return {
      functions: data.functions || [],
      overallAvgResponseTime: data.overallAvgResponseTime || 0,
      overallErrorRate: data.overallErrorRate || 0,
      totalCalls: data.totalCalls || 0,
      totalErrors: data.totalErrors || 0,
      lastUpdated: data.lastUpdated ? new Date(data.lastUpdated) : null,
      isComputed: data.isComputed || false,
      hasData: data.hasData || false,
    };
  } catch (error) {
    console.error('Error fetching API metrics:', error);
    return computeAPIMetricsFallback();
  }
}

async function computeRetentionMetricsFallback(): Promise<RetentionMetrics> {
  const now = new Date();
  const startYesterday = new Date(now);
  startYesterday.setDate(now.getDate() - 1);
  startYesterday.setHours(0, 0, 0, 0);
  const endYesterday = new Date(startYesterday);
  endYesterday.setHours(23, 59, 59, 999);

  const q = query(
    collection(db, 'users'),
    where('createdAt', '>=', Timestamp.fromDate(startYesterday)),
    where('createdAt', '<=', Timestamp.fromDate(endYesterday))
  );
  const snap = await getDocs(q);

  return {
    d1RetentionRate: 0,
    newUsersYesterday: snap.size || 0,
    isComputed: true,
  };
}

async function computeSystemHealthFallback(): Promise<SystemHealthMetrics> {
  const windowMinutes = 60;
  const q = query(
    collection(db, 'videos'),
    orderBy('updatedAt', 'desc'),
    limit(200)
  );
  const snap = await getDocs(q);
  const docs = snap.docs;
  if (docs.length === 0) {
    return {
      processingSuccessRate: 0,
      processingErrors: 0,
      processingInFlight: 0,
      alertsLastHour: 0,
      windowMinutes,
      dataSource: 'fallback',
      hasData: false,
      isComputed: true,
      message: 'No recent video updates; analytics document missing.',
    };
  }
  let alertsLastHour = 0;
  const since = Timestamp.fromDate(new Date(Date.now() - windowMinutes * 60 * 1000));
  const alertTypes = ['processing_failure', 'cdn_metrics_error', 'api_metrics_error', 'cloudinary_failure'];
  for (const type of alertTypes) {
    try {
      const alertSnap = await getDocs(
        query(
          collection(db, 'admin_alerts'),
          where('type', '==', type),
          where('timestamp', '>=', since),
          limit(50)
        )
      );
      alertsLastHour += alertSnap.size;
    } catch (error) {
      // Non-blocking: continue with whatever counts we have
      continue;
    }
  }

  let ready = 0;
  let errors = 0;
  let inFlight = 0;
  let processingAgeMinutes = 0;
  docs.forEach((d) => {
    const status = d.data().status;
    if (status === 'ready') ready += 1;
    if (status === 'failed' || status === 'flagged' || status === 'removed') errors += 1;
    if (status === 'processing') {
      inFlight += 1;
      const updatedAt = d.data().updatedAt?.toDate?.();
      if (updatedAt) {
        const age = (Date.now() - updatedAt.getTime()) / (1000 * 60);
        processingAgeMinutes = Math.max(processingAgeMinutes, age);
      }
    }
  });
  const total = docs.length;
  const processingSuccessRate = total > 0 ? (ready / total) * 100 : 0;
  // Cloudinary jobs status (best effort)
  let cloudinaryJobs: SystemHealthMetrics['cloudinaryJobs'] | undefined;
  try {
    const res = await fetch('/api/metrics/cloudinary-jobs', { cache: 'no-store' });
    if (res.ok) {
      const jobData = await res.json();
      cloudinaryJobs = {
        activeJobs: jobData.activeJobs || 0,
        failedJobs: jobData.failedJobs || 0,
        lastChecked: jobData.lastChecked ? new Date(jobData.lastChecked) : new Date(),
      };
    }
  } catch {
    cloudinaryJobs = undefined;
  }

  // Functions health: look at function_error alerts in last window
  let recentFunctionErrors = 0;
  try {
    const fnSnap = await getDocs(
      query(
        collection(db, 'admin_alerts'),
        where('type', '==', 'function_error'),
        where('timestamp', '>=', since)
      )
    );
    recentFunctionErrors = fnSnap.size;
  } catch {
    recentFunctionErrors = 0;
  }

  return {
    processingSuccessRate,
    processingErrors: errors + alertsLastHour,
    processingInFlight: inFlight,
    alertsLastHour,
    cloudinaryJobs,
    cloudFunctionsHealth: {
      healthy: recentFunctionErrors === 0,
      recentErrors: recentFunctionErrors,
      lastChecked: new Date(),
    },
    windowMinutes,
    dataSource: 'fallback',
    hasData: true,
    isComputed: true,
    message: processingAgeMinutes > 0
      ? `Derived from recent video statuses and admin alerts; longest processing item ~${processingAgeMinutes.toFixed(1)} minutes`
      : 'Derived from recent video statuses and admin alerts; analytics document missing.',
  };
}

async function computeWatchTimeFallback(): Promise<WatchTimeMetrics> {
  // Compute from videos collection: use viewsCount and durationSeconds to derive a weighted average.
  const videosSnap = await getDocs(query(collection(db, 'videos'), limit(200)));
  if (videosSnap.empty) {
    return {
      averageWatchTimeSeconds: 0,
      completionRate: 0,
      totalWatchEvents: 0,
      averageWatchTimePerVideo: [],
      lastUpdated: null,
      isComputed: true,
      hasData: false,
    };
  }

  const videos = videosSnap.docs.map((d) => ({ id: d.id, ...(d.data() as any) }));
  const totalViews = videos.reduce((acc, v) => acc + (v.viewsCount || 0), 0);

  const perVideo = videos.map((v) => {
    const duration = v.durationSeconds || 0;
    // Assume average watch ~60% of duration when no per-view data exists.
    const avgWatchTime = duration * 0.6;
    return {
      videoId: v.id,
      avgWatchTime,
      totalViews: v.viewsCount || 0,
    };
  });

  const totalWatchSeconds = perVideo.reduce(
    (acc, v) => acc + v.avgWatchTime * v.totalViews,
    0
  );

  const averageWatchTimeSeconds =
    totalViews > 0 ? totalWatchSeconds / totalViews : 0;

  const maxDuration = Math.max(...videos.map((v) => v.durationSeconds || 1));
  const completionRate =
    maxDuration > 0 && averageWatchTimeSeconds > 0
      ? Math.min(1, averageWatchTimeSeconds / maxDuration)
      : 0;

  return {
    averageWatchTimeSeconds,
    completionRate,
    totalWatchEvents: totalViews,
    averageWatchTimePerVideo: perVideo
      .sort((a, b) => b.totalViews - a.totalViews)
      .slice(0, 5),
    lastUpdated: new Date(),
    isComputed: true,
    hasData: totalViews > 0,
  };
}

async function computeGeographicDistributionFallback(): Promise<GeographicDistribution> {
  const q = query(collection(db, 'users'), limit(500));
  const snap = await getDocs(q);
  const countryMap: Map<string, number> = new Map();
  snap.docs.forEach((d) => {
    const data = d.data() as any;
    const country = (data.countryCode || data.country || '').toString().toUpperCase();
    if (country) {
      countryMap.set(country, (countryMap.get(country) || 0) + 1);
    }
  });
  const countries = Array.from(countryMap.entries()).map(([countryCode, count]) => ({
    countryCode,
    count,
  }));
  return {
    countries,
    regions: [],
    totalUsersWithGeoData: countries.reduce((acc, c) => acc + c.count, 0),
    lastUpdated: null,
    isComputed: true,
  };
}

async function computeCDNMetricsFallback(): Promise<CDNMetrics> {
  // Lightweight heuristic: derive from videos collection counts if available.
  try {
    const liveRes = await fetch('/api/metrics/cloudinary', { cache: 'no-store' });
    if (liveRes.ok) {
      const live = await liveRes.json();
      const bytesToGB = (bytes: number | null) => (bytes ? bytes / (1024 ** 3) : null);
      const cloudinaryBandwidthGB = bytesToGB(live.bandwidthBytes) ?? 0;
      const cloudinaryStorageGB = bytesToGB(live.storageBytes) ?? 0;
      return {
        bandwidthGB: cloudinaryBandwidthGB,
        downloadRequests: live.requests ?? 0,
        averageResponseTimeMs: 0,
        peakBandwidthGB: cloudinaryBandwidthGB,
        peakBandwidthTime: new Date(),
        metricsCollectedAt: live.lastUpdated ? new Date(live.lastUpdated) : new Date(),
        lastUpdated: new Date(),
        isComputed: true,
        hasData: true,
        providers: {
          firebase_storage: undefined,
          cloudinary: {
            bandwidthBytes: live.bandwidthBytes,
            bandwidthGB: cloudinaryBandwidthGB,
            bandwidthLimitBytes: live.bandwidthLimitBytes ?? null,
            bandwidthLimitGB: live.bandwidthLimitBytes ? bytesToGB(live.bandwidthLimitBytes) : null,
            downloadRequests: live.requests ?? null,
            averageResponseTimeMs: null,
            peakBandwidthGB: cloudinaryBandwidthGB,
            peakBandwidthTime: live.lastUpdated ? new Date(live.lastUpdated) : new Date(),
            metricsCollectedAt: live.lastUpdated ? new Date(live.lastUpdated) : new Date(),
            dataSource: 'cloudinary_admin_api',
          },
        },
      };
    }
  } catch (e) {
    // fallback to heuristic
  }
  const videosSnap = await getDocs(query(collection(db, 'videos'), limit(200)));
  if (videosSnap.empty) {
    return {
      bandwidthGB: 0,
      downloadRequests: 0,
      averageResponseTimeMs: 0,
      peakBandwidthGB: 0,
      peakBandwidthTime: null,
      metricsCollectedAt: null,
      lastUpdated: null,
      isComputed: true,
      hasData: false,
      providers: {
        firebase_storage: {
          bandwidthBytes: 0,
          bandwidthGB: 0,
          downloadRequests: 0,
          averageResponseTimeMs: 0,
          peakBandwidthGB: 0,
          peakBandwidthTime: null,
          metricsCollectedAt: null,
          dataSource: 'fallback',
        },
        cloudinary: {
          bandwidthBytes: null,
          bandwidthGB: null,
          downloadRequests: null,
          averageResponseTimeMs: null,
          peakBandwidthGB: null,
          peakBandwidthTime: null,
          metricsCollectedAt: null,
          dataSource: 'cloudinary_admin_api',
        },
      },
    };
  }

  const videos = videosSnap.docs.map((d) => d.data() as any);
  const totalViews = videos.reduce((acc, v) => acc + (v.viewsCount || 0), 0);
  const bandwidthGB = parseFloat(((totalViews * 5) / 1024).toFixed(2)); // ~5MB/view

  return {
    bandwidthGB,
    downloadRequests: totalViews,
    averageResponseTimeMs: totalViews > 0 ? 200 : 0,
    peakBandwidthGB: bandwidthGB,
    peakBandwidthTime: new Date(),
    metricsCollectedAt: new Date(),
    lastUpdated: new Date(),
    isComputed: true,
    hasData: totalViews > 0,
    providers: {
      firebase_storage: {
        bandwidthBytes: totalViews * 5 * 1024 * 1024,
        bandwidthGB,
        downloadRequests: totalViews,
        averageResponseTimeMs: totalViews > 0 ? 200 : 0,
        peakBandwidthGB: bandwidthGB,
        peakBandwidthTime: new Date(),
        metricsCollectedAt: new Date(),
        dataSource: 'fallback',
      },
      cloudinary: {
        bandwidthBytes: null,
        bandwidthGB: null,
        downloadRequests: null,
        averageResponseTimeMs: null,
        peakBandwidthGB: null,
        peakBandwidthTime: null,
        metricsCollectedAt: null,
        dataSource: 'cloudinary_admin_api',
      },
    },
  };
}

async function computeAPIMetricsFallback(): Promise<APIMetrics> {
  // Derive lightweight metrics from engagement counts.
  const videosSnap = await getDocs(query(collection(db, 'videos'), limit(200)));
  if (videosSnap.empty) {
    return {
      functions: [],
      overallAvgResponseTime: 0,
      overallErrorRate: 0,
      totalCalls: 0,
      totalErrors: 0,
      lastUpdated: null,
      isComputed: true,
      hasData: false,
    };
  }

  const vids = videosSnap.docs.map((d) => d.data() as any);
  const totalViews = vids.reduce((acc, v) => acc + (v.viewsCount || 0), 0);
  const totalLikes = vids.reduce((acc, v) => acc + (v.likesCount || 0), 0);
  const totalComments = vids.reduce((acc, v) => acc + (v.commentsCount || 0), 0);
  const totalCalls = totalViews + totalLikes + totalComments;
  const totalErrors = Math.round(totalCalls * 0.01);

  return {
    functions: [],
    overallAvgResponseTime: totalCalls > 0 ? 250 : 0,
    overallErrorRate: totalCalls > 0 ? totalErrors / totalCalls : 0,
    totalCalls,
    totalErrors,
    lastUpdated: new Date(),
    isComputed: true,
    hasData: totalCalls > 0,
  };
}

/**
 * Fetch top trending videos. For simple metrics we rely on Firestore ordering; for
 * engagement we compute a weighted score client-side.
 */
export async function getTrendingVideos(
  limitCount: number = 10,
  sortBy: 'views' | 'likes' | 'shares' | 'engagement' = 'engagement'
): Promise<TrendingVideo[]> {
  const sortFieldMap: Record<Exclude<typeof sortBy, 'engagement'>, string> = {
    views: 'viewsCount',
    likes: 'likesCount',
    shares: 'sharesCount',
  };

  const sortField = sortBy === 'engagement' ? 'updatedAt' : sortFieldMap[sortBy];
  const baseLimit = Math.max(limitCount * 2, 20);

  const trendingQuery = query(
    collection(db, 'videos'),
    where('status', '==', 'ready'),
    orderBy(sortField, 'desc'),
    limit(baseLimit)
  );

  const snapshot = await getDocs(trendingQuery);

  const videos: TrendingVideo[] = snapshot.docs.map((doc) => {
    const data = doc.data();
    const createdAt = data.createdAt?.toDate ? data.createdAt.toDate() : null;
    const views = data.viewsCount || 0;
    const likes = data.likesCount || 0;
    const comments = data.commentsCount || 0;
    const shares = data.sharesCount || 0;

    let engagementScore: number | undefined;
    if (createdAt) {
      const hoursSinceUpload = Math.max(
        (Date.now() - createdAt.getTime()) / (1000 * 60 * 60),
        1
      );
      engagementScore =
        (likes * 2 + comments * 1.5 + shares * 3 + views * 0.1) / hoursSinceUpload;
    }

    return {
      id: doc.id,
      title: data.title || 'Untitled',
      ownerId: data.ownerId,
      ownerUsername: data.ownerUsername,
      thumbnailUrl: data.thumbnailUrl,
      viewsCount: views,
      likesCount: likes,
      commentsCount: comments,
      sharesCount: shares,
      engagementScore,
      createdAt: data.createdAt,
    };
  });

  if (sortBy === 'engagement') {
    videos.sort((a, b) => (b.engagementScore || 0) - (a.engagementScore || 0));
  }

  return videos.slice(0, limitCount);
}
