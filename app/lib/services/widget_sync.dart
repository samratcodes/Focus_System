import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../api.dart';
import '../logic.dart';
import '../models.dart';
import '../platform.dart';
import 'notifications.dart';

/// Feeds the Android home-screen widget (TasksWidgetProvider.kt).
///
/// The widget reads plain values from the shared "HomeWidgetPreferences":
///   signed_in, date_label, done_count, total_count, tasks_json,
///   focus_running, focus_ends_at (local epoch ms), focus_label, focus_task
class HomeWidgetSync {
  static const qualifiedAndroidName = 'com.focussystem.focus_system.TasksWidgetProvider';
  static const iOSName = 'FocusTasksWidget';

  static Future<void> push(Bootstrap data, {required int serverOffset}) async {
    if (!supportsDeviceFeatures) return;
    try {
      final today = todayStr();
      final goals = {for (final g in data.goals) g.id: g};
      final list = tasksForDate(data.tasks, today)..sort((a, b) {
        if (a.completed != b.completed) return a.completed ? 1 : -1;
        if (a.isPriority != b.isPriority) return a.isPriority ? -1 : 1;
        return (timeToMinutes(a.startTime) ?? 9999).compareTo(timeToMinutes(b.startTime) ?? 9999);
      });
      final tasksJson = jsonEncode([
        for (final t in list)
          {
            'id': t.id,
            'title': t.title,
            'completed': t.completed,
            'priority': t.isPriority,
            'time': t.startTime ?? '',
            'goal': t.goalId == null ? '' : (goals[t.goalId]?.title ?? ''),
            'color': t.goalId == null ? '' : (goals[t.goalId]?.color ?? ''),
            'subtasks': t.subtasks.isEmpty ? '' : '${t.subtasks.where((s) => s.completed).length}/${t.subtasks.length}',
          },
      ]);
      final f = data.focus;
      final attached = f.attachedTaskId == null ? null : data.tasks.where((t) => t.id == f.attachedTaskId).firstOrNull;

      await Future.wait([
        HomeWidget.saveWidgetData<bool>('signed_in', true),
        HomeWidget.saveWidgetData<String>('date_label', fmtDate(today)),
        HomeWidget.saveWidgetData<int>('done_count', list.where((t) => t.completed).length),
        HomeWidget.saveWidgetData<int>('total_count', list.length),
        HomeWidget.saveWidgetData<String>('tasks_json', tasksJson),
        HomeWidget.saveWidgetData<bool>('focus_running', f.running && f.endsAt != null),
        HomeWidget.saveWidgetData<String>(
          'focus_ends_at',
          f.endsAt == null ? '0' : (f.endsAt! - serverOffset).toString(),
        ),
        HomeWidget.saveWidgetData<String>('focus_label', focusModeLabel(f.mode)),
        HomeWidget.saveWidgetData<String>('focus_paused_clock', fmtClock(f.secondsLeft)),
        HomeWidget.saveWidgetData<String>('focus_task', attached?.title ?? ''),
      ]);
      await HomeWidget.updateWidget(qualifiedAndroidName: qualifiedAndroidName, iOSName: iOSName);
    } catch (e) {
      debugPrint('Widget update failed: $e');
    }
  }

  static Future<void> signedOut() async {
    if (!supportsDeviceFeatures) return;
    try {
      await HomeWidget.saveWidgetData<bool>('signed_in', false);
      await HomeWidget.saveWidgetData<String>('tasks_json', '[]');
      await HomeWidget.saveWidgetData<bool>('focus_running', false);
      await HomeWidget.updateWidget(qualifiedAndroidName: qualifiedAndroidName, iOSName: iOSName);
    } catch (_) {}
  }
}

/// Runs in a background isolate when the widget's checkbox / refresh / focus
/// buttons are tapped (the app does not need to be open).
///   focussystem://toggle?id=TASK_ID&completed=true|false
///   focussystem://refresh
///   focussystem://focus?action=start|pause
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;
  try {
    final api = await Api.fromSession();
    if (api.token == null) return;
    switch (uri.host) {
      case 'toggle':
        final id = uri.queryParameters['id'];
        if (id != null) {
          await api.patch('/api/tasks/$id', {'completed': uri.queryParameters['completed'] == 'true'});
        }
      case 'focus':
        final action = uri.queryParameters['action'];
        if (action == 'start' || action == 'pause') await api.post('/api/focus', {'action': action});
    }
    final data = Bootstrap.fromJson(await api.get('/api/bootstrap'));
    final offset = data.serverTime - DateTime.now().millisecondsSinceEpoch;
    await HomeWidgetSync.push(data, serverOffset: offset);
    if (uri.host == 'focus') {
      await Notifications.init();
      final attached = data.focus.attachedTaskId;
      await Notifications.syncFocus(
        data.focus,
        data.user.settings,
        serverOffset: offset,
        taskTitle: attached == null ? null : data.tasks.where((t) => t.id == attached).firstOrNull?.title,
      );
    }
  } catch (e) {
    debugPrint('Widget action failed: $e');
    // The widget flipped the checkbox optimistically; undo it since the server call failed.
    final id = uri.queryParameters['id'];
    if (uri.host == 'toggle' && id != null) {
      final raw = await HomeWidget.getWidgetData<String>('tasks_json');
      if (raw != null) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        for (final t in list) {
          if (t['id'] == id) t['completed'] = uri.queryParameters['completed'] != 'true';
        }
        await HomeWidget.saveWidgetData<String>('tasks_json', jsonEncode(list));
      }
    }
    await HomeWidget.updateWidget(
      qualifiedAndroidName: HomeWidgetSync.qualifiedAndroidName,
      iOSName: HomeWidgetSync.iOSName,
    );
  }
}
