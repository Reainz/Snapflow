import { NextResponse } from 'next/server';
import { getAdminAuth, getAdminFirestore } from '@/lib/firebase/admin';

export const runtime = 'nodejs';

export async function GET(request: Request) {
  try {
    // Verify admin token
    const token = request.headers.get('authorization')?.replace(/^[Bb]earer\s+/, '');
    if (!token) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const auth = getAdminAuth();
    const decoded = await auth.verifyIdToken(token);
    if (decoded.admin !== true) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
    }

    // Parse query params
    const url = new URL(request.url);
    const type = url.searchParams.get('type');
    
    if (!type) {
      return NextResponse.json({ error: 'Missing type parameter' }, { status: 400 });
    }

    const db = getAdminFirestore();
    
    // Build the query based on type
    let queryRef = db.collection('analytics').where('type', '==', type);
    
    // For api_metrics, prefer the most recent document (hourly aggregation runs more frequently than daily).
    
    // Order by appropriate timestamp field
    const orderField = type === 'cdn_metrics' ? 'timestamp' : 'createdAt';
    const snapshot = await queryRef.orderBy(orderField, 'desc').limit(1).get();

    if (snapshot.empty) {
      return NextResponse.json(null);
    }

    const doc = snapshot.docs[0];
    const data = doc.data();

    // Process based on type
    if (type === 'cdn_metrics') {
      const metrics = data.metrics || {};
      const providers = data.providers || {};
      const firebaseStorage = providers.firebase_storage || {};
      const cloudinary = providers.cloudinary || {};

      const num = (value: unknown, fallback = 0): number =>
        typeof value === 'number' && Number.isFinite(value) ? value : fallback;

      const iso = (value: any): string | null =>
        value?.toDate?.() instanceof Date ? value.toDate().toISOString() : null;
      
      return NextResponse.json({
        bandwidthGB: num(data.totalBandwidthGB ?? metrics.bandwidthGB ?? firebaseStorage.bandwidthGB),
        downloadRequests: num(
          data.totalRequests ??
            metrics.downloadRequests ??
            firebaseStorage.downloadRequests ??
            metrics.totalRequests
        ),
        averageResponseTimeMs: num(
          data.averageResponseTimeMs ?? metrics.averageResponseTimeMs ?? firebaseStorage.averageResponseTimeMs
        ),
        peakBandwidthGB: num(data.peakBandwidthGB ?? metrics.peakBandwidthGB ?? firebaseStorage.peakBandwidthGB),
        peakBandwidthTime: iso(data.peakBandwidthTime ?? metrics.peakBandwidthTime ?? firebaseStorage.peakBandwidthTime),
        metricsCollectedAt: iso(firebaseStorage.metricsCollectedAt) ?? data.collectedAt ?? null,
        lastUpdated: data.timestamp?.toDate?.()?.toISOString() || null,
        isComputed: false,
        hasData:
          num(data.totalBandwidthGB ?? metrics.bandwidthGB ?? firebaseStorage.bandwidthGB) > 0 ||
          num(data.totalRequests ?? metrics.downloadRequests ?? firebaseStorage.downloadRequests) > 0 ||
          Boolean(firebaseStorage.dataSource) ||
          Boolean(cloudinary.dataAvailable),
        providers: {
          firebase_storage: providers.firebase_storage || null,
          cloudinary: providers.cloudinary
            ? {
                ...providers.cloudinary,
                downloadRequests:
                  providers.cloudinary.downloadRequests ?? providers.cloudinary.requests ?? null,
              }
            : null,
        },
      });
    }
    
    if (type === 'api_metrics') {
      const metrics = data.metrics || {};
      const sourceMetrics = metrics.functions ? metrics : data;

      const num = (value: unknown, fallback = 0): number =>
        typeof value === 'number' && Number.isFinite(value) ? value : fallback;

      const maxReasonableMs = 15 * 60 * 1000; // 15 minutes
      const clampMs = (value: unknown): number => {
        const ms = num(value, 0);
        return ms >= 0 && ms <= maxReasonableMs ? ms : 0;
      };

      const functions = Array.isArray(sourceMetrics.functions) ? sourceMetrics.functions : [];
      const sanitizedFunctions = functions.map((fn: any) => ({
        name: String(fn?.name ?? ''),
        avgResponseTimeMs: clampMs(fn?.avgResponseTimeMs),
        errorRate: Math.max(0, Math.min(1, num(fn?.errorRate, 0))),
        totalCalls: Math.max(0, Math.trunc(num(fn?.totalCalls, 0))),
        p95ResponseTimeMs: clampMs(fn?.p95ResponseTimeMs),
        errors: Math.max(0, Math.trunc(num(fn?.errors, 0))),
      }));
      
      return NextResponse.json({
        functions: sanitizedFunctions,
        overallAvgResponseTime: clampMs(sourceMetrics.overallAvgResponseTime),
        overallErrorRate: Math.max(0, Math.min(1, num(sourceMetrics.overallErrorRate, 0))),
        totalCalls: Math.max(0, Math.trunc(num(sourceMetrics.totalCalls, 0))),
        totalErrors: Math.max(0, Math.trunc(num(sourceMetrics.totalErrors, 0))),
        lastUpdated: data.createdAt?.toDate?.()?.toISOString() || null,
        isComputed: false,
        hasData: sanitizedFunctions.length > 0 || num(sourceMetrics.totalCalls, 0) > 0,
      });
    }

    // Generic response for other types
    return NextResponse.json(data);
  } catch (error: any) {
    console.error('Analytics API error:', error?.message);
    return NextResponse.json({ error: error?.message || 'Unable to fetch analytics' }, { status: 500 });
  }
}
