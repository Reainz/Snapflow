import { NextResponse } from 'next/server';

export async function POST(request: Request) {
  try {
    const { token, expiresIn } = await request.json();
    if (!token) {
      return NextResponse.json({ error: 'Missing token' }, { status: 400 });
    }
    const maxAge = typeof expiresIn === 'number' ? expiresIn : 60 * 60; // default 1h
    const response = NextResponse.json({ ok: true });
    response.cookies.set({
      name: '__session',
      value: token,
      httpOnly: true,
      sameSite: 'lax',
      path: '/',
      maxAge,
      secure: true,
    });
    return response;
  } catch (e) {
    return NextResponse.json({ error: 'Unable to set session' }, { status: 400 });
  }
}
