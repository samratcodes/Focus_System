# Focus System — website (Next.js frontend)

The web UI. It has no database of its own: every `/api/*` request is forwarded to the
[backend](../backend) (Node.js + Express + Prisma), so the website and the app share the same data.

```bash
npm install
cp .env.example .env       # BACKEND_URL defaults to http://localhost:4000
npm run dev                # http://localhost:3000  (start the backend first)
```

## How it talks to the backend

- `next.config.ts` rewrites `/api/:path*` → `BACKEND_URL/api/:path*`. The browser stays on one origin, so the
  backend's httpOnly session cookie works without CORS.
- `src/app/(app)/layout.tsx` loads the first page's data on the server with `GET /api/bootstrap` (no loading flash).
- `src/proxy.ts` sends visitors without a session cookie to `/login`.

## Layout

```
src/app/(auth)/            /login, /register
src/app/(app)/             Today, Calendar, Focus, Analytics, Settings
src/components/            sidebar, header, task card, task editor, focus overlay…
src/lib/client/            store (optimistic updates + 30 s sync), timer, toasts, dialogs, sounds
src/lib/shared/            API types + pure helpers
src/app/globals.css        the original styles.css, unchanged, plus additions at the end
```
