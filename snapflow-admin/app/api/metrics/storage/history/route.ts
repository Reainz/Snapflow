import { NextResponse } from 'next/server';
import { Timestamp } from 'firebase-admin/firestore';
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

    // Parse query params for date range
    const url = new URL(request.url);
    const startParam = url.searchParams.get('start');
    const endParam = url.searchParams.get('end');
    
    const start = startParam ? new Date(startParam) : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const end = endParam ? new Date(endParam) : new Date();

    const db = getAdminFirestore();
    
    const snapshot = await db.collection('analytics')
      .where('type', '==', 'storage_metrics')
      .where('timestamp', '>=', Timestamp.fromDate(start))
      .where('timestamp', '<=', Timestamp.fromDate(end))
      .orderBy('timestamp', 'asc')
      .get();

    if (snapshot.empty) {
      return NextResponse.json([]);
    }

    const history = snapshot.docs.map(doc => {
      const data = doc.data();
      const timestamp = data.timestamp?.toDate() || new Date();
      
      return {
        date: timestamp.toISOString().split('T')[0],
        totalSizeGB: data.totalSizeGB || 0,
        totalFiles: data.totalFiles || 0,
        timestamp: timestamp.toISOString(),
      };
    });

    return NextResponse.json(history);
  } catch (error: any) {
    console.error('Storage history error:', error?.message);
    return NextResponse.json({ error: error?.message || 'Unable to fetch storage history' }, { status: 500 });
  }
}