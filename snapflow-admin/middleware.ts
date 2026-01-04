import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

const PUBLIC_PATHS = ['/login', '/_next', '/favicon.ico'];
const PUBLIC_API_PATHS = ['/api/auth/set-session', '/api/auth/clear-session', '/api/auth/verify'];

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const isApiRoute = pathname.startsWith('/api');

  const isPublic =
    PUBLIC_PATHS.some((path) => pathname.startsWith(path)) ||
    PUBLIC_API_PATHS.some((path) => pathname === path);
  if (isPublic) {
    return NextResponse.next();
  }

  const tokenFromCookie = request.cookies.get('__session')?.value;
  const authHeader = request.headers.get('authorization');
  const bearer = authHeader?.toLowerCase().startsWith('bearer ')
    ? authHeader.substring(7)
    : null;
  const idToken = tokenFromCookie || bearer;

  if (!idToken) {
    if (isApiRoute) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    return NextResponse.redirect(new URL('/login', request.url));
  }

  // For edge middleware, we just check if token exists
  // The actual admin verification happens in API routes using Firebase Admin SDK
  // This is because edge middleware can't use Firebase Admin SDK directly
  
  // Pass the token in a header for API routes to verify
  const requestHeaders = new Headers(request.headers);
  requestHeaders.set('x-session-token', idToken);
  
  return NextResponse.next({
    request: {
      headers: requestHeaders,
    },
  });
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|login).*)'],
};
