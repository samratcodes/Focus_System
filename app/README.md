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
