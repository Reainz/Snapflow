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
    
    // For api_metrics, filter by period
    if (type === 'api_metrics') {
      queryRef = queryRef.where('period', '==', 'daily');
    }
    
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
      
      return NextResponse.json({
        bandwidthGB: data.totalBandwidthGB ?? metrics.bandwidthGB ?? 0,
        downloadRequests: data.totalRequests ?? metrics.downloadRequests ?? 0,
        averageResponseTimeMs: data.averageResponseTimeMs ?? metrics.averageResponseTimeMs ?? 0,
        peakBandwidthGB: data.peakBandwidthGB ?? metrics.peakBandwidthGB ?? 0,
        peakBandwidthTime: data.peakBandwidthTime || metrics.peakBandwidthTime || null,
        metricsCollectedAt: data.collectedAt || null,
        lastUpdated: data.timestamp?.toDate?.()?.toISOString() || null,
        isComputed: false,
        hasData: true,
        providers: {
          firebase_storage: providers.firebase_storage || null,
          cloudinary: providers.cloudinary || null,
        },
      });
    }
    
    if (type === 'api_metrics') {
      const metrics = data.metrics || {};
      const sourceMetrics = metrics.functions ? metrics : data;
      
      return NextResponse.json({
        functions: sourceMetrics.functions || [],
        overallAvgResponseTime: sourceMetrics.overallAvgResponseTime || 0,
        overallErrorRate: sourceMetrics.overallErrorRate || 0,
        totalCalls: sourceMetrics.totalCalls || 0,
        totalErrors: sourceMetrics.totalErrors || 0,
        lastUpdated: data.createdAt?.toDate?.()?.toISOString() || null,
        isComputed: false,
        hasData: (sourceMetrics.functions?.length > 0) || (sourceMetrics.totalCalls ?? 0) > 0,
      });
    }

    // Generic response for other types
    return NextResponse.json(data);
  } catch (error: any) {
    console.error('Analytics API error:', error?.message);
    return NextResponse.json({ error: error?.message || 'Unable to fetch analytics' }, { status: 500 });
  }
}