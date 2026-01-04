import { NextResponse } from 'next/server';
import { getAdminAuth, getAdminFirestore } from '@/lib/firebase/admin';

export const runtime = 'nodejs';

interface AdminSettings {
  autoRefreshInterval: number;
  dateFormat: string;
  theme: 'light' | 'dark' | 'system';
}

const DEFAULT_SETTINGS: AdminSettings = {
  autoRefreshInterval: 30,
  dateFormat: 'MM/DD/YYYY',
  theme: 'system',
};

async function verifyAdminToken(request: Request): Promise<string | null> {
  const token = request.headers.get('authorization')?.replace(/^[Bb]earer\s+/, '');
  if (!token) return null;

  try {
    const auth = getAdminAuth();
    const decoded = await auth.verifyIdToken(token);
    if (decoded.admin !== true) return null;
    return decoded.uid;
  } catch {
    return null;
  }
}

export async function GET(request: Request) {
  const userId = await verifyAdminToken(request);
  if (!userId) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    const db = getAdminFirestore();
    const ref = db.collection('admin_settings').doc(userId);
    const snap = await ref.get();

    if (!snap.exists) {
      return NextResponse.json(DEFAULT_SETTINGS);
    }

    const data = snap.data() || {};
    return NextResponse.json({
      autoRefreshInterval: data.autoRefreshInterval ?? DEFAULT_SETTINGS.autoRefreshInterval,
      dateFormat: data.dateFormat ?? DEFAULT_SETTINGS.dateFormat,
      theme: data.theme ?? DEFAULT_SETTINGS.theme,
    });
  } catch (error) {
    console.error('Error fetching settings:', error);
    return NextResponse.json(DEFAULT_SETTINGS);
  }
}

export async function POST(request: Request) {
  const userId = await verifyAdminToken(request);
  if (!userId) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    const body = await request.json();
    const db = getAdminFirestore();
    const ref = db.collection('admin_settings').doc(userId);
    
    const settings: Partial<AdminSettings> = {};
    if (typeof body.autoRefreshInterval === 'number') {
      settings.autoRefreshInterval = body.autoRefreshInterval;
    }
    if (typeof body.dateFormat === 'string') {
      settings.dateFormat = body.dateFormat;
    }
    if (['light', 'dark', 'system'].includes(body.theme)) {
      settings.theme = body.theme;
    }

    await ref.set(settings, { merge: true });
    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error saving settings:', error);
    return NextResponse.json({ error: 'Failed to save settings' }, { status: 500 });
  }
}