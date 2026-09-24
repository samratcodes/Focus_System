# Focus System

Plan today. Do one thing at a time. The website and the mobile app are **one product**:
the same account, the same data and the same focus timer — served by one Node.js backend.

**Live**

| Part | URL | Hosting |
| --- | --- | --- |
| Website | https://focus-system-amber.vercel.app | Vercel project `focus-system` (root `website/`) |
| Backend API | https://focus-system-api.vercel.app ([health](https://focus-system-api.vercel.app/api/health)) | Vercel project `focus-system-api` (root `backend/`) |
| Database | Neon PostgreSQL (us-east-2) | connection strings live only in Vercel env vars / local `.env` |
| Android app | `app/build/app/outputs/flutter-apk/app-release.apk` | uses the live API by default |

```
Focus System/
├── backend/   Node.js + Express + Prisma — the REST API and the database (one backend for everything)
├── website/   Next.js 16 frontend — the web UI; forwards /api/* to the backend
├── app/       Flutter app (Android/iOS) — same UI and theme; calls the backend directly
├── dev.bat    starts backend + website together (Windows)
└── *.html, shared.js, styles.css, server.js   the original localStorage-only version (kept for reference)
```

```
 ┌─────────────┐ cookie ┌───────────────────┐  /api/*   ┌───────────────────────────┐
 │  Browser    │──────▶ │ website/  :3000   │ ────────▶ │ backend/  :4000            │
 └─────────────┘        │ Next.js (UI only) │  proxied  │ Node.js + Express          │
                        └───────────────────┘           │ REST API, JWT auth, zod    │──▶ Prisma ──▶ SQLite / Postgres
 ┌─────────────┐          Bearer token (JWT)            │                            │    (one database)
 │ Flutter app │ ─────────────────────────────────────▶ │                            │
 │ + widget    │                                        └───────────────────────────┘
 └─────────────┘
```

## What's in it

Everything from the original, rebuilt on a real backend:

- **Today** – daily board, 7-day strip, "pick the main task" (priority / eat-the-frog), quick add, goal filters, subtasks.
- **Calendar** – month grid with task dots and priority markers, per-day composer, read-only past days.
- **Focus** – Pomodoro timer (work / short / long break), attach a task, YouTube focus music, alarm, full-screen mode.
- **Analytics** – completion, daily average, focus time, best day, day-by-day bars, goal breakdown, Eisenhower matrix.
- **Gamification** – XP (task +20, priority task +50, subtask +5, focus session +25), levels every 100 XP, streaks.

New:

- **Accounts** – register / sign in / sign out / sign out everywhere / change password / delete account.
- **Sync** – website and app share one database. The focus timer lives on the server, so a timer started on the
  laptop is running on the phone (and in the widget) too. Clients re-sync on focus/resume and every 30 s.
- **Mobile notifications** – live countdown in the notification shade (with Pause / Skip buttons), alarms when
  each session or break ends (even if the app is closed), and reminders before tasks with a start time.
- **Android home-screen widget** (like Google Tasks) – today's tasks with tick-off checkboxes, progress,
  quick add, refresh, and a live focus countdown with start/pause.
- **Fixes** – un-checking a task now takes its XP back (no more XP farming); editing subtasks in the task
  editor no longer discards other unsaved edits; renamed subtasks are saved; exactly-once XP when several
  devices see a session finish at the same moment; styled dialogs instead of `prompt()` / `confirm()`.
- **Data** – one-click import of the old version's data (detected automatically in the same browser),
  JSON import/export, browser notification + countdown in the tab title while a session runs.

## Quick start

Requirements: Node.js 20+, Flutter 3.29+ (for the app).

### 1. Backend (Node.js + Express + Prisma)

```bash
cd backend
npm install                 # also generates the Prisma client
cp .env.example .env        # set DATABASE_URL / DIRECT_URL (Neon) and AUTH_SECRET
npx prisma migrate deploy   # creates the tables in the Postgres database
npm run dev                 # API on http://localhost:4000
```

### 2. Website

```bash
cd website
npm install
cp .env.example .env        # BACKEND_URL=http://localhost:4000
npm run dev                 # http://localhost:3000
```

Open http://localhost:3000, create an account, and you're in. If you used the old version in this browser,
a banner offers to import that data. On Windows, double-click **`dev.bat`** to start the backend and the website together.

> Port 3000 busy? `npx next dev -p 3100` — the app is unaffected, it talks to the backend on port 4000.

### 3. Flutter app

```bash
cd app
flutter pub get
flutter run                 # Android emulator or a connected phone
```

On the sign-in screen open **Server** and enter the **backend** address:

| Where the app runs           | Server address                                   |
| ---------------------------- | ------------------------------------------------ |
| Android emulator             | `http://10.0.2.2:4000` (the default)             |
| Physical phone on your Wi-Fi | `http://<your PC's IP>:4000` (the backend listens on all interfaces) |
| Deployed backend             | `https://api.your-domain`                         |

You can also bake the address in: `flutter run --dart-define=API_URL=https://api.your-domain`.

Then long-press the home screen → **Widgets** → **Focus System · Today** (or Settings → *Add widget to home screen*).

## API

Served by `backend/`. All endpoints are JSON. Auth is either the `fs_session` cookie (website) or
`Authorization: Bearer <token>` (app). Clients send `X-Timezone: <IANA zone>` so "today" is the user's local day.

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/api/auth/register` | `{name,email,password,timezone}` → `{user, token}` |
| POST | `/api/auth/login` | `{email,password,timezone}` → `{user, token}` |
| POST | `/api/auth/logout` | `{everywhere?: true}` |
| GET / PATCH / DELETE | `/api/auth/me` | profile · change name/password · delete account |
| GET | `/api/bootstrap` | everything a client needs (user, goals, tasks, focus logs, streak, timer) |
| GET / POST | `/api/tasks` | list (`?from=&to=`) · create |
| GET / PATCH / DELETE | `/api/tasks/:id` | read · update (incl. `completed`, `isPriority`) · delete |
| POST | `/api/tasks/:id/subtasks` | add subtask |
| PATCH / DELETE | `/api/tasks/:id/subtasks/:subId` | rename / complete · delete |
| GET / POST | `/api/goals` | list · create |
| PATCH / DELETE | `/api/goals/:id` | update · delete (tasks become uncategorized) |
| GET / POST | `/api/focus` | timer state (advances finished phases) · `{action: start\|pause\|reset\|skip\|attach}` |
| PATCH | `/api/settings` | timer lengths, YouTube link, alarm, reminder lead time |
| POST | `/api/import` | import data in the original localStorage format |
| GET | `/api/health` | used by the app's "Test connection" |

XP-changing responses include `events: [{amount, reason, total, level, leveledUp}]`, which both clients show as toasts.

## Going to production

1. **Backend** – already on Postgres (Neon). Set `DATABASE_URL`, `DIRECT_URL` and a strong `AUTH_SECRET`,
   then deploy `backend/` to Vercel (zero-config Express; `vercel-build` applies migrations) or any Node host.

2. **Website** – deploy `website/` (e.g. Vercel) with `BACKEND_URL` and `NEXT_PUBLIC_API_URL` set to the backend URL.
3. **App** – `flutter build apk --dart-define=API_URL=https://api.your-domain`, and remove
   `android:usesCleartextTraffic="true"` from `app/android/app/src/main/AndroidManifest.xml`.

## Tests

```bash
cd backend && npm run typecheck && npm run test:api     # 52 end-to-end API checks (backend must be running)
cd website && npm run typecheck && npm run lint
cd app && flutter analyze && flutter test
```

The app also runs in a browser for quick UI checks (notifications and the widget are phone-only and are
skipped there): `cd app && flutter run -d chrome --dart-define=API_URL=http://localhost:4000`.

Install on a phone without the emulator: `cd app && flutter build apk --debug --dart-define=API_URL=http://<PC-IP>:4000`,
then copy `app/build/app/outputs/flutter-apk/app-debug.apk` to the phone (or `adb install` it).
