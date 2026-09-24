# Focus System — Flutter app

Same account, data and look as the website (colours are copied from the site's CSS tokens, icons are Lucide
like the web). It talks to the Node.js backend in [../backend](../backend) — see the [root README](../README.md).

```bash
flutter pub get
flutter run                                   # server defaults to http://10.0.2.2:4000 (emulator → backend on your PC)
flutter run --dart-define=API_URL=http://192.168.1.20:4000   # or set it on the sign-in screen
```

## Layout

```
lib/main.dart                       app entry, registers widget + notification callbacks
lib/app_state.dart                  store: bootstrap, optimistic mutations, XP toasts, 30 s sync, timer ticking
lib/api.dart                        HTTP client + session (token in secure storage)
lib/models.dart, lib/logic.dart     API models and helpers (ports of the website's shared code)
lib/theme.dart                      colours / radii from the website CSS
lib/screens/                        login, today, calendar, focus (+ full screen), analytics, settings
lib/widgets/                        task card, task editor sheet, shared UI pieces
lib/services/notifications.dart     live countdown notification, phase-end alarms, task reminders
lib/services/widget_sync.dart       feeds the home-screen widget; handles widget taps in the background
android/app/src/main/kotlin/…       TasksWidgetProvider / TasksWidgetService / WidgetActionActivity
android/app/src/main/res/layout/    widget_tasks.xml, widget_task_item.xml
```

## Notifications & alarms

- While a session runs, an ongoing notification shows a live countdown with **Pause** (and **Skip break**).
- Alarms are scheduled for the next 8 phase ends, so they ring even if the app is closed. The first time you
  start a timer, Android asks for notification permission and (Android 12+) "Alarms & reminders".
- Task reminders fire before any task with a start time (lead time set in Settings, shared with the website).

## Home-screen widget (Android)

Shows today's tasks (open first, priority on top), a progress bar, a focus strip with a live countdown and
start/pause, plus refresh and "+" (opens the app on a new task). Ticking a checkbox updates instantly and syncs
in the background without opening the app. When a focus phase ends, the widget fetches the next phase by itself.

iOS: the app, notifications and sync work; a home-screen widget needs a WidgetKit extension added in Xcode
(`home_widget` reads the same keys; iOS name `FocusTasksWidget`).

## Release builds & Google Play

Release builds are signed with **your upload key**, not the debug key:

- `android/app/upload-keystore.jks` — the keystore
- `android/key.properties` — its passwords (`storePassword`, `keyPassword`, `keyAlias=upload`)

Both are git-ignored. **Back them up somewhere safe** (password manager / private drive). With Play App
Signing, Google can reset a lost upload key, but it takes time.

```bash
flutter build apk --release          # build/app/outputs/flutter-apk/app-release.apk  (install on a phone)
flutter build appbundle --release    # build/app/outputs/bundle/release/app-release.aab (upload to Play Console)
```

Security / Play readiness built in:

- HTTPS only in release (`usesCleartextTraffic=false`; debug builds allow http for a local backend)
- No backups of app data (`allowBackup=false`, data-extraction rules) — the session token stays on the device
- Code + resource shrinking (R8) with `res/raw/keep.xml` so notification icons are kept
- In-app account deletion (Settings → Delete account) and a public privacy policy
  (https://focus-system-amber.vercel.app/privacy), both required by Google Play
- Target SDK 35; exact alarms via `SCHEDULE_EXACT_ALARM` only (no Play-restricted `USE_EXACT_ALARM`)

Before bumping a new version to Play, increase `version:` in `pubspec.yaml` (e.g. `1.0.1+2`).
