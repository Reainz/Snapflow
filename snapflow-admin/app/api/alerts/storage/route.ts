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
    const acknowledged = url.searchParams.get('acknowledged');

    const db = getAdminFirestore();
    
    let q = db.collection('admin_alerts')
      .where('type', '==', 'storage_warning')
      .orderBy('timestamp', 'desc');
    
    // Add acknowledged filter if specified
    if (acknowledged !== null) {
      q = db.collection('admin_alerts')
        .where('type', '==', 'storage_warning')
        .where('acknowledged', '==', acknowledged === 'true')
        .orderBy('timestamp', 'desc');
    }

    const snapshot = await q.get();

    const alerts = snapshot.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        type: data.type || 'storage_warning',
        severity: data.severity || 'info',
        message: data.message || '',
        threshold: data.threshold || 0,
        currentValue: data.currentValue || 0,
        acknowledged: data.acknowledged || false,
        createdAt: data.createdAt?.toDate?.()?.toISOString() || data.timestamp?.toDate?.()?.toISOString() || null,
      };
    });

    return NextResponse.json(alerts);
  } catch (error: any) {
    console.error('Storage alerts error:', error?.message);
    return NextResponse.json({ error: error?.message || 'Unable to fetch storage alerts' }, { status: 500 });
  }
}
