import { NextResponse } from 'next/server';
import { getStorage } from 'firebase-admin/storage';
import { getAdminAuth, getAdminFirestore, initializeFirebaseAdmin } from '@/lib/firebase/admin';

export const runtime = 'nodejs';

export async function GET(request: Request) {
  try {
    // Verify admin token
    const token = request.headers.get('authorization')?.replace(/^[Bb]earer\s+/, '');
    if (!token) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    // Initialize Firebase Admin and get services
    initializeFirebaseAdmin();
    
    const auth = getAdminAuth();
    const decoded = await auth.verifyIdToken(token);
    if (decoded.admin !== true) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
    }

    const db = getAdminFirestore();
    
    // First try to get from analytics collection
    const analyticsSnap = await db.collection('analytics')
      .where('type', '==', 'storage_metrics')
      .orderBy('timestamp', 'desc')
      .limit(1)
      .get();

    if (!analyticsSnap.empty) {
      const doc = analyticsSnap.docs[0];
      const data = doc.data();
      const timestamp = data.timestamp?.toDate() || new Date();
      
      return NextResponse.json({
        id: doc.id,
        type: data.type,
        totalSizeGB: data.totalSizeGB || 0,
        totalSizeMB: data.totalSizeMB || 0,
        totalFiles: data.totalFiles || 0,
        bucketStats: data.bucketStats || {
          'raw-videos': { count: 0, sizeGB: '0.00', sizeMB: '0.00' },
          'thumbnails': { count: 0, sizeGB: '0.00', sizeMB: '0.00' },
          'captions': { count: 0, sizeGB: '0.00', sizeMB: '0.00' },
          'profile-pictures': { count: 0, sizeGB: '0.00', sizeMB: '0.00' },
          'other': { count: 0, sizeGB: '0.00', sizeMB: '0.00' },
        },
        cloudinaryMetrics: data.cloudinaryMetrics || null,
        timestamp,
        collectedAt: data.collectedAt || timestamp.toISOString(),
        isComputed: false,
      });
    }

    // Fallback: compute live from Firebase Storage
    const bucket = getStorage().bucket();
    const [files] = await bucket.getFiles({ maxResults: 200 });

    let totalSize = 0;
    let totalFiles = 0;
    const bucketStats: Record<string, { count: number; size: number }> = {
      'raw-videos': { count: 0, size: 0 },
      thumbnails: { count: 0, size: 0 },
      captions: { count: 0, size: 0 },
      'profile-pictures': { count: 0, size: 0 },
      other: { count: 0, size: 0 },
    };

    files.forEach((file) => {
      const size = parseInt(String(file.metadata.size || '0'), 10);
      totalSize += size;
      totalFiles += 1;

      const prefixes = ['raw-videos', 'thumbnails', 'captions', 'profile-pictures'];
      const match = prefixes.find((p) => file.name.startsWith(p));
      if (match) {
        bucketStats[match].count += 1;
        bucketStats[match].size += size;
      } else {
        bucketStats.other.count += 1;
        bucketStats.other.size += size;
      }
    });

    const formatBucket = (stats: { count: number; size: number }) => ({
      count: stats.count,
      sizeGB: (stats.size / (1024 ** 3)).toFixed(2),
      sizeMB: (stats.size / (1024 ** 2)).toFixed(2),
    });

    const timestamp = new Date();

    return NextResponse.json({
      id: 'live-storage',
      type: 'storage_metrics',
      totalSizeGB: totalSize / (1024 ** 3),
      totalSizeMB: totalSize / (1024 ** 2),
      totalFiles,
      bucketStats: {
        'raw-videos': formatBucket(bucketStats['raw-videos']),
        thumbnails: formatBucket(bucketStats.thumbnails),
        captions: formatBucket(bucketStats.captions),
        'profile-pictures': formatBucket(bucketStats['profile-pictures']),
        other: formatBucket(bucketStats.other),
      },
      timestamp,
      collectedAt: timestamp.toISOString(),
      isComputed: true,
    });
  } catch (error: any) {
    console.error('Storage metrics error:', error?.message);
    return NextResponse.json({ error: error?.message || 'Unable to fetch storage metrics' }, { status: 500 });
  }
}
