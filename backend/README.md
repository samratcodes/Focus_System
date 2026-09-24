# Focus System — backend (Node.js + Express + Prisma)

The one backend for the product. The **website** and the **Flutter app** both use this API and the same database.

```bash
npm install                 # also runs `prisma generate`
cp .env.example .env        # set DATABASE_URL / DIRECT_URL (Neon) and AUTH_SECRET
npx prisma migrate deploy   # creates the tables in the Postgres database
npm run dev                 # http://localhost:4000  (auto-reloads)
npm run test:api            # 52 end-to-end API checks against the running server
```

## Layout

```
prisma/schema.prisma      database schema (PostgreSQL on Neon): User, Goal, Task, Subtask, PomoLog, StreakDay, FocusState
prisma/migrations/        SQL migrations
src/server.ts             entry: exports the app (Vercel) or listens on PORT (local)
src/create-app.ts         Express app: helmet, CORS, JSON, cookies, routes, error handler
src/config.ts             environment variables
src/routes/               auth, tasks (+ subtasks), goals, focus + bootstrap + settings, import
src/lib/                  auth (bcrypt + JWT), focus timer engine, XP/streaks, zod validation, DTOs
src/shared/               types + pure helpers (same as the website's src/lib/shared)
scripts/api-smoke-test.mjs
```

## Auth

- `POST /api/auth/register` / `login` return `{ user, token }` **and** set an httpOnly `fs_session` cookie.
- The app sends `Authorization: Bearer <token>`; the website relies on the cookie (its `/api/*` is proxied here).
- Tokens are JWT (HS256, 30 days). Changing the password or "sign out everywhere" bumps `tokenVersion`,
  which invalidates every existing token.
- Clients send `X-Timezone` so "today" and the no-past-dates rules follow the user's local day.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `DATABASE_URL` | — (required) | Neon **pooled** Postgres URL (host contains `-pooler`) |
| `DIRECT_URL` | — (required) | Neon **direct** Postgres URL, used by migrations |
| `AUTH_SECRET` | — (required) | JWT signing secret, ≥ 32 chars |
| `PORT` | `4000` | HTTP port (listens on all interfaces so phones on your Wi-Fi can connect) |
| `CORS_ORIGINS` | `http://localhost:3000` | Browser origins allowed to call the API with cookies |

## Production (Vercel)

Deployed as a Vercel project with root directory `backend/` (zero-config Express: `src/server.ts` default-exports
the app). `vercel-build` runs `prisma generate`, `prisma migrate deploy` and `tsc`. Set `DATABASE_URL`, `DIRECT_URL`,
`AUTH_SECRET` and `CORS_ORIGINS` (the website URL) in the project's environment variables.

The full endpoint list is in the [root README](../README.md#api).
