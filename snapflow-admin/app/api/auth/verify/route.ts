import { NextResponse } from 'next/server';
import { getAdminAuth } from '@/lib/firebase/admin';

export const runtime = 'nodejs';

export async function POST(request: Request) {
  const token = request.headers.get('authorization')?.replace(/^[Bb]earer\s+/, '');
  if (!token) {
    return NextResponse.json({ error: 'Missing token' }, { status: 401 });
  }

  try {
    const auth = getAdminAuth();
    const decoded = await auth.verifyIdToken(token);
    if (decoded.admin === true) {
      return NextResponse.json({ admin: true }, { status: 200 });
    }
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  } catch (error: any) {
    console.error('Verify API error:', error?.message || error);
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }
}
