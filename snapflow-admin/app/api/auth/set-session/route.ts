import { NextResponse } from 'next/server';

export async function POST(request: Request) {
  try {
    const { token, expiresIn } = await request.json();
    if (!token) {
      return NextResponse.json({ error: 'Missing token' }, { status: 400 });
    }
    const maxAge = typeof expiresIn === 'number' ? expiresIn : 60 * 60; // default 1h
    const proto = request.headers.get('x-forwarded-proto') || new URL(request.url).protocol.replace(':', '');
    const secure = proto === 'https';
    const response = NextResponse.json({ ok: true });
    response.cookies.set({
      name: '__session',
      value: token,
      httpOnly: true,
      sameSite: 'lax',
      path: '/',
      maxAge,
      secure,
    });
    return response;
  } catch (e) {
    return NextResponse.json({ error: 'Unable to set session' }, { status: 400 });
  }
}
