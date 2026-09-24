import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../api.dart';
import '../logic.dart';
import '../models.dart';
import '../platform.dart';
import 'widget_sync.dart';

/// Local notifications:
///  * an ongoing notification with a live countdown while the focus timer runs,
///  * alarms at every upcoming phase end (even if the app is killed),
///  * reminders before tasks that have a start time.
class Notifications {
  static final plugin = FlutterLocalNotificationsPlugin();

  static const _focusOngoingId = 1000;
  static const _focusAlarmBaseId = 1001; // 1001..1008
  static const _maxScheduledPhases = 8;
  static const _taskPayloadPrefix = 'task:';

  static const _chFocusTimer = AndroidNotificationChannel(
    'focus_timer',
    'Focus timer',
    description: 'Shows the running focus countdown',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );
  static const _chFocusAlarm = AndroidNotificationChannel(
    'focus_alarm',
    'Focus alarms',
    description: 'Rings when a focus session or break ends',
    importance: Importance.max,
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );
  static const _chFocusQuiet = AndroidNotificationChannel(
    'focus_updates',
    'Focus updates (silent)',
    description: 'Session ended notices when the alarm is turned off',
    importance: Importance.defaultImportance,
    playSound: false,
  );
  static const _chReminders = AndroidNotificationChannel(
    'task_reminders',
    'Task reminders',
    description: 'Reminds you before a task starts',
    importance: Importance.high,
  );

  /// Payloads of notifications the user tapped (e.g. "focus", "task:ID").
  static final taps = StreamController<String>.broadcast();
  static String? launchPayload;
  static bool _ready = false;

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> init() async {
    if (_ready || !supportsDeviceFeatures) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await Api.timeZone()));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_focus'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );
    final android = _android;
    if (android != null) {
      for (final ch in [_chFocusTimer, _chFocusAlarm, _chFocusQuiet, _chReminders]) {
        await android.createNotificationChannel(ch);
      }
    }
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) launchPayload = launch!.notificationResponse?.payload;
    _ready = true;
  }

  /// Asks for notification permission, and once for exact alarms (Android 12+).
  static Future<void> requestPermissions() async {
    if (!supportsDeviceFeatures) return;
    try {
      await _requestPermissions();
    } catch (e) {
      debugPrint('Permission request failed: $e');
    }
  }

  static Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return;
    }
    final android = _android;
    if (android == null) return;
    await android.requestNotificationsPermission();
    final prefs = await SharedPreferences.getInstance();
    if (!(await android.canScheduleExactNotifications() ?? true) && !(prefs.getBool('asked_exact_alarm') ?? false)) {
      await prefs.setBool('asked_exact_alarm', true);
      await android.requestExactAlarmsPermission();
    }
  }

  static Future<bool> _canExact() async {
    try {
      return await _android?.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return false;
    }
  }

  static Future<AndroidScheduleMode> _scheduleMode() async =>
      await _canExact() ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;

  /// Phase-end alarms: "alarm clock" mode fires on time even in Doze/battery saver.
  static Future<AndroidScheduleMode> _alarmMode() async =>
      await _canExact() ? AndroidScheduleMode.alarmClock : AndroidScheduleMode.inexactAllowWhileIdle;

  static void _onResponse(NotificationResponse r) {
    if (r.actionId == 'pause' || r.actionId == 'skip') {
      // App is open: run it, then let AppState re-sync.
      unawaited(_runFocusAction(r.actionId!).then((_) => taps.add('refresh')));
      return;
    }
    if (r.payload != null) taps.add(r.payload!);
  }

  // ---------------------------------------------------------------- focus

  /// Mirrors the server timer into notifications. [serverOffset] = server - local clock (ms).
  static Future<void> syncFocus(FocusState f, UserSettings s, {required int serverOffset, String? taskTitle}) async {
    if (!_ready) return;
    try {
      await _syncFocus(f, s, serverOffset: serverOffset, taskTitle: taskTitle);
    } catch (e) {
      debugPrint('Focus notifications failed: $e');
    }
  }

  static Future<void> _syncFocus(FocusState f, UserSettings s, {required int serverOffset, String? taskTitle}) async {
    await plugin.cancel(_focusOngoingId);
    for (var i = 0; i < _maxScheduledPhases; i++) {
      await plugin.cancel(_focusAlarmBaseId + i);
    }
    if (!f.running || f.endsAt == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final endsLocal = f.endsAt! - serverOffset;
    if (endsLocal <= now) return;
    final isWork = f.mode == 'work';

    await plugin.show(
      _focusOngoingId,
      '${focusModeLabel(f.mode)} · ${s.phaseSeconds(f.mode) ~/ 60} min',
      taskTitle ?? (isWork ? 'Deep work session' : 'Take a breather'),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _chFocusTimer.id,
          _chFocusTimer.name,
          channelDescription: _chFocusTimer.description,
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          showWhen: true,
          when: endsLocal,
          usesChronometer: true,
          chronometerCountDown: true,
          timeoutAfter: endsLocal - now,
          category: AndroidNotificationCategory.stopwatch,
          color: isWork ? const Color(0xFF6366F1) : const Color(0xFF10B981),
          colorized: true,
          visibility: NotificationVisibility.public,
          actions: [
            const AndroidNotificationAction('pause', 'Pause', cancelNotification: false),
            if (!isWork) const AndroidNotificationAction('skip', 'Skip break', cancelNotification: false),
          ],
        ),
      ),
      payload: 'focus',
    );

    // The server keeps cycling work → break → work, so schedule the next few phase ends.
    // Each alarm also counts down the phase it starts, so a break (or the next focus
    // session) stays visible in the shade even while the app is closed.
    final mode = await _alarmMode();
    var phase = f.mode;
    var sessions = f.sessionCount;
    var at = endsLocal;
    final channel = s.alarmEnabled ? _chFocusAlarm : _chFocusQuiet;
    for (var i = 0; i < _maxScheduledPhases; i++) {
      final String title;
      final String body;
      if (phase == 'work') {
        sessions++;
        phase = sessions % s.pomoLongInterval == 0 ? 'longBreak' : 'shortBreak';
        final breakMin = s.phaseSeconds(phase) ~/ 60;
        title = 'Focus session complete 🎉 +25 XP';
        body =
            phase == 'longBreak'
                ? 'Long break ($breakMin min) — stand up, stretch, get some water.'
                : 'Short break ($breakMin min) — rest your eyes.';
      } else {
        phase = 'work';
        title = 'Break over ☕';
        body = 'Next focus session: ${s.pomoWork} minutes. You got this.';
      }
      final phaseMs = s.phaseSeconds(phase) * 1000;
      await plugin.zonedSchedule(
        _focusAlarmBaseId + i,
        title,
        body,
        tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, at),
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: channel.importance,
            priority: s.alarmEnabled ? Priority.max : Priority.defaultPriority,
            category: AndroidNotificationCategory.alarm,
            audioAttributesUsage: s.alarmEnabled ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
            playSound: s.alarmEnabled,
            color: phase == 'work' ? const Color(0xFF6366F1) : const Color(0xFF10B981),
            // Live countdown of the phase that just started (break or next focus).
            showWhen: true,
            when: at + phaseMs,
            usesChronometer: true,
            chronometerCountDown: true,
            timeoutAfter: phaseMs,
            actions: [
              if (phase != 'work') const AndroidNotificationAction('skip', 'Skip break', cancelNotification: true),
              const AndroidNotificationAction('pause', 'Pause', cancelNotification: true),
            ],
          ),
          iOS: DarwinNotificationDetails(
            presentSound: s.alarmEnabled,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: mode,
        payload: 'focus',
      );
      at += phaseMs;
    }
  }

  // ---------------------------------------------------------------- tasks

  static int _taskNotificationId(String taskId) {
    var h = 0;
    for (final c in taskId.codeUnits) {
      h = (h * 31 + c) & 0x3fffffff;
    }
    return 10000 + h % 1000000;
  }

  /// Re-schedules reminders for the next 7 days of tasks that have a start time.
  static Future<void> syncTaskReminders(List<Task> tasks, int reminderMinutes) async {
    if (!_ready) return;
    try {
      await _syncTaskReminders(tasks, reminderMinutes);
    } catch (e) {
      debugPrint('Task reminders failed: $e');
    }
  }

  static Future<void> _syncTaskReminders(List<Task> tasks, int reminderMinutes) async {
    for (final p in await plugin.pendingNotificationRequests()) {
      if (p.payload?.startsWith(_taskPayloadPrefix) ?? false) await plugin.cancel(p.id);
    }
    if (reminderMinutes < 0) return;

    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 7));
    final mode = await _scheduleMode();
    for (final t in tasks) {
      if (t.completed || t.startTime == null) continue;
      final day = parseDate(t.dueDate);
      final mins = timeToMinutes(t.startTime)!;
      final start = DateTime(day.year, day.month, day.day, mins ~/ 60, mins % 60);
      final at = start.subtract(Duration(minutes: reminderMinutes));
      if (at.isBefore(now) || at.isAfter(horizon)) continue;
      await plugin.zonedSchedule(
        _taskNotificationId(t.id),
        t.title,
        reminderMinutes == 0 ? 'Starting now · ${t.startTime}' : 'Starts in $reminderMinutes min · ${t.startTime}',
        tz.TZDateTime.from(at, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _chReminders.id,
            _chReminders.name,
            channelDescription: _chReminders.description,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            color: t.isPriority ? const Color(0xFFF97316) : const Color(0xFF6366F1),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: mode,
        payload: '$_taskPayloadPrefix${t.id}',
      );
    }
  }

  static Future<void> cancelAll() async {
    if (_ready) await plugin.cancelAll();
  }
}

/// Pause / Skip pressed on the notification while the app is in the background.
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse r) {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  if (r.actionId == 'pause' || r.actionId == 'skip') unawaited(_runFocusAction(r.actionId!));
}

Future<void> _runFocusAction(String action) async {
  try {
    final api = await Api.fromSession();
    if (api.token == null) return;
    await api.post('/api/focus', {'action': action});
    final data = Bootstrap.fromJson(await api.get('/api/bootstrap'));
    final offset = data.serverTime - DateTime.now().millisecondsSinceEpoch;
    await Notifications.init();
    final attached = data.focus.attachedTaskId;
    await Notifications.syncFocus(
      data.focus,
      data.user.settings,
      serverOffset: offset,
      taskTitle: attached == null ? null : data.tasks.where((t) => t.id == attached).firstOrNull?.title,
    );
    await HomeWidgetSync.push(data, serverOffset: offset);
  } catch (e) {
    debugPrint('Focus action from notification failed: $e');
  }
}
