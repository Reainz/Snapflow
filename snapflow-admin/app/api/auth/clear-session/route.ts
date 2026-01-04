import { NextResponse } from 'next/server';

export async function POST(request: Request) {
  const proto = request.headers.get('x-forwarded-proto') || new URL(request.url).protocol.replace(':', '');
  const secure = proto === 'https';
  const response = NextResponse.json({ ok: true });
  response.cookies.set({
    name: '__session',
    value: '',
    httpOnly: true,
    sameSite: 'lax',
    path: '/',
    maxAge: 0,
    secure,
  });
  return response;
}
