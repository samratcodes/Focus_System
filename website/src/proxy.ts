import { NextResponse, type NextRequest } from "next/server";

const SESSION_COOKIE = "fs_session";
const AUTH_PAGES = ["/login", "/register"];
const PUBLIC_PAGES = ["/privacy"];

/**
 * Optimistic page guard based on the presence of the session cookie. The real
 * check happens in the backend: an invalid cookie makes (app)/layout.tsx send
 * the visitor through /api/auth/logout, which clears it.
 */
export function proxy(request: NextRequest) {
  const { pathname, search } = request.nextUrl;
  if (PUBLIC_PAGES.includes(pathname)) return NextResponse.next();
  const signedIn = request.cookies.has(SESSION_COOKIE);
  const isAuthPage = AUTH_PAGES.includes(pathname);

  if (!signedIn && !isAuthPage) {
    const url = new URL("/login", request.url);
    if (pathname !== "/") url.searchParams.set("next", pathname + search);
    return NextResponse.redirect(url);
  }
  if (signedIn && isAuthPage) {
    return NextResponse.redirect(new URL("/", request.url));
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!api|_next/static|_next/image|favicon.ico|icon.svg|.*\\.(?:png|svg|ico|webmanifest)$).*)"],
};
