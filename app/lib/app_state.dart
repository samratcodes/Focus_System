import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

import 'api.dart';
import 'logic.dart';
import 'models.dart';
import 'services/notifications.dart';
import 'services/widget_sync.dart';

enum ToastType { normal, success, error, info }

/// App-wide state. Mirrors the website's store (website/src/lib/client/store.tsx):
/// one bootstrap payload from the server, optimistic mutations, XP toasts from
/// server events, and periodic re-sync so web and phone stay in step.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  Api api = Api(baseUrl: defaultApiUrl);
  Bootstrap? _data;
  bool booting = true;
  bool online = true;
  int serverOffset = 0; // server clock - local clock (ms)

  // UI state shared between screens (like the web's `ui` object)
  int tab = 0;
  String? activeGoalId;
  String selectedDate = todayStr();
  int calendarMonth = DateTime.now().month;
  int calendarYear = DateTime.now().year;
  String analyticsPeriod = 'week';
  String searchQuery = '';

  /// Remaining seconds of the focus phase, ticking once a second.
  final secondsLeft = ValueNotifier<int>(0);

  void Function(String message, ToastType type)? onToast;
  void Function(String payload)? onOpenPayload;

  Timer? _ticker;
  Timer? _poll;
  Timer? _sideEffectsDebounce;
  bool _advancing = false;
  int _lastAdvance = 0;
  bool _refreshing = false;
  StreamSubscription<String>? _tapSub;

  Bootstrap get data => _data!;
  bool get signedIn => _data != null;
  String get today => todayStr();

  // ------------------------------------------------------------ lifecycle

  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    _tapSub = Notifications.taps.stream.listen(_handlePayload);
    api = await Api.fromSession();
    if (api.token != null) await refresh();
    booting = false;
    notifyListeners();
    if (signedIn) unawaited(Notifications.requestPermissions());
    final launch = Notifications.launchPayload;
    if (launch != null) {
      Notifications.launchPayload = null;
      _handlePayload(launch);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tapSub?.cancel();
    _ticker?.cancel();
    _poll?.cancel();
    _sideEffectsDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (signedIn) refresh();
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _poll?.cancel();
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (signedIn) refresh();
    });
  }

  void _handlePayload(String payload) {
    if (payload == 'refresh') {
      refresh();
      return;
    }
    if (payload == 'focus') setTab(2);
    if (payload.startsWith('task:') || payload == 'today') setTab(0);
    onOpenPayload?.call(payload);
  }

  void setTab(int i) {
    tab = i;
    notifyListeners();
  }

  void setUi(VoidCallback change) {
    change();
    notifyListeners();
  }

  // ------------------------------------------------------------ auth

  /// Returns an error message, or null on success.
  Future<String?> authenticate({
    required String serverUrl,
    required String email,
    required String password,
    String? name,
  }) async {
    final url = Session.normalizeUrl(serverUrl);
    final client = Api(baseUrl: url);
    try {
      final tz = await Api.timeZone();
      final res =
          name == null
              ? await client.post('/api/auth/login', {'email': email, 'password': password, 'timezone': tz})
              : await client.post('/api/auth/register', {
                'name': name,
                'email': email,
                'password': password,
                'timezone': tz,
              });
      final token = res['token'] as String?;
      if (token == null) return 'Unexpected response from server';
      await Session.setBaseUrl(url);
      await Session.setToken(token);
      api = Api(baseUrl: url, token: token);
      await refresh(throwOnError: true);
      _startPolling();
      unawaited(Notifications.requestPermissions());
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> logout({bool everywhere = false, String? message}) async {
    try {
      if (everywhere) await api.post('/api/auth/logout', {'everywhere': true});
    } catch (_) {}
    await Session.setToken(null);
    api = Api(baseUrl: api.baseUrl);
    _data = null;
    _ticker?.cancel();
    _poll?.cancel();
    await Notifications.cancelAll();
    await HomeWidgetSync.signedOut();
    notifyListeners();
    if (message != null) _toast(message, ToastType.info);
  }

  // ------------------------------------------------------------ sync

  Future<void> refresh({bool throwOnError = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final res = await api.get('/api/bootstrap');
      _setData(Bootstrap.fromJson(res));
      online = true;
      handleEvents(_data!.events);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await logout(message: 'Your session expired. Please sign in again.');
      } else if (e.isOffline) {
        online = false;
        notifyListeners();
      }
      if (throwOnError) rethrow;
    } finally {
      _refreshing = false;
    }
  }

  void _setData(Bootstrap b) {
    _data = b;
    serverOffset = b.serverTime - DateTime.now().millisecondsSinceEpoch;
    _restartTicker();
    notifyListeners();
    _scheduleSideEffects();
  }

  void _update(Bootstrap Function(Bootstrap d) fn) {
    if (_data == null) return;
    _data = fn(_data!);
    _restartTicker();
    notifyListeners();
    _scheduleSideEffects();
  }

  Bootstrap _copy({User? user, List<Goal>? goals, List<Task>? tasks, List<String>? streakDays, FocusState? focus}) {
    final d = _data!;
    return Bootstrap(
      user: user ?? d.user,
      goals: goals ?? d.goals,
      tasks: tasks ?? d.tasks,
      pomoLogs: d.pomoLogs,
      streakDays: streakDays ?? d.streakDays,
      focus: focus ?? d.focus,
      events: const [],
      serverTime: d.serverTime,
    );
  }

  /// Widget + notifications follow the data, batched so bursts of edits cost one update.
  void _scheduleSideEffects() {
    _sideEffectsDebounce?.cancel();
    _sideEffectsDebounce = Timer(const Duration(milliseconds: 400), () async {
      final d = _data;
      if (d == null) return;
      await HomeWidgetSync.push(d, serverOffset: serverOffset);
      final attached = d.focus.attachedTaskId;
      await Notifications.syncFocus(
        d.focus,
        d.user.settings,
        serverOffset: serverOffset,
        taskTitle: attached == null ? null : d.tasks.where((t) => t.id == attached).firstOrNull?.title,
      );
      await Notifications.syncTaskReminders(d.tasks, d.user.settings.reminderMinutes);
    });
  }

  void _toast(String msg, ToastType type) => onToast?.call(msg, type);

  void handleEvents(List<XpEvent> events) {
    if (events.isEmpty || _data == null) return;
    for (final e in events) {
      if (e.leveledUp) {
        _toast('🎉 LEVEL UP! You reached Level ${e.level}!', ToastType.success);
      } else if (e.amount > 0) {
        _toast('+${e.amount} XP: ${e.reason}', ToastType.success);
      }
    }
    _data = _copy(user: _data!.user.copyWith(xp: events.last.total));
    notifyListeners();
  }

  Future<void> _fail(Object e) async {
    if (e is ApiException) {
      if (e.isUnauthorized) return logout(message: 'Your session expired. Please sign in again.');
      if (e.isOffline) online = false;
      _toast(e.message, ToastType.error);
    } else {
      _toast('Something went wrong', ToastType.error);
    }
    notifyListeners();
  }

  // ------------------------------------------------------------ focus timer

  int _computeSeconds() {
    final f = _data?.focus;
    if (f == null) return 0;
    if (!f.running || f.endsAt == null) return f.secondsLeft;
    final ms = f.endsAt! - (DateTime.now().millisecondsSinceEpoch + serverOffset);
    return max(0, (ms / 1000).ceil());
  }

  void _restartTicker() {
    _ticker?.cancel();
    secondsLeft.value = _computeSeconds();
    if (_data?.focus.running ?? false) {
      _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
        secondsLeft.value = _computeSeconds();
        if (secondsLeft.value <= 0) _advancePhase();
      });
    }
  }

  /// A phase ended: the server logs the session, awards XP and starts the next phase.
  Future<void> _advancePhase() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_advancing || now - _lastAdvance < 3000) return;
    _advancing = true;
    _lastAdvance = now;
    final prev = _data!.focus;
    try {
      final res = await api.get('/api/focus');
      serverOffset = (res['serverTime'] as num).toInt() - DateTime.now().millisecondsSinceEpoch;
      final next = FocusState.fromJson(res['focus'] as Map<String, dynamic>);
      _update((d) => _copy(focus: next));
      handleEvents(XpEvent.listFrom(res['events']));
      if (next.version != prev.version && prev.mode != 'work') {
        _toast('Break over! Ready to focus.', ToastType.info);
      }
      // Session logs / pomodoro counts changed on the server.
      if (prev.mode == 'work') unawaited(refresh());
    } catch (_) {
      // Offline: retry on the next tick window.
    } finally {
      _advancing = false;
    }
  }

  Future<void> focusAction(String action) async {
    try {
      final res = await api.post('/api/focus', {'action': action});
      serverOffset = (res['serverTime'] as num).toInt() - DateTime.now().millisecondsSinceEpoch;
      _update((d) => _copy(focus: FocusState.fromJson(res['focus'] as Map<String, dynamic>)));
      handleEvents(XpEvent.listFrom(res['events']));
      if (action == 'start') unawaited(Notifications.requestPermissions());
    } catch (e) {
      await _fail(e);
    }
  }

  Future<void> attachTask(String? taskId) async {
    _update((d) => _copy(focus: d.focus.withAttached(taskId)));
    try {
      final res = await api.post('/api/focus', {'action': 'attach', 'taskId': taskId});
      _update((d) => _copy(focus: FocusState.fromJson(res['focus'] as Map<String, dynamic>)));
    } catch (e) {
      await _fail(e);
    }
  }

  Future<bool> updateSettings(Map<String, Object?> patch) async {
    try {
      final res = await api.patch('/api/settings', patch);
      _update(
        (d) => _copy(
          user: User.fromJson(res['user'] as Map<String, dynamic>),
          focus: FocusState.fromJson(res['focus'] as Map<String, dynamic>),
        ),
      );
      return true;
    } catch (e) {
      await _fail(e);
      return false;
    }
  }

  // ------------------------------------------------------------ tasks

  void _putTask(Task task) {
    _update((d) {
      final exists = d.tasks.any((t) => t.id == task.id);
      var tasks = exists ? d.tasks.map((t) => t.id == task.id ? task : t).toList() : [...d.tasks, task];
      if (task.isPriority) {
        tasks = tasks.map((t) => t.id != task.id && t.isPriority ? t.copyWith(isPriority: false) : t).toList();
      }
      return _copy(tasks: tasks);
    });
  }

  void _patchLocal(String id, Task Function(Task t) fn) {
    _update((d) => _copy(tasks: d.tasks.map((t) => t.id == id ? fn(t) : t).toList()));
  }

  Future<Task?> createTask(Map<String, Object?> body) async {
    try {
      final res = await api.post('/api/tasks', body);
      final task = Task.fromJson(res['task'] as Map<String, dynamic>);
      _putTask(task);
      if (!data.streakDays.contains(today)) _update((d) => _copy(streakDays: [...d.streakDays, today]));
      return task;
    } catch (e) {
      await _fail(e);
      return null;
    }
  }

  Future<Task?> updateTask(String id, Map<String, Object?> patch) async {
    try {
      final res = await api.patch('/api/tasks/$id', patch);
      final task = Task.fromJson(res['task'] as Map<String, dynamic>);
      _putTask(task);
      handleEvents(XpEvent.listFrom(res['events']));
      return task;
    } catch (e) {
      await _fail(e);
      unawaited(refresh());
      return null;
    }
  }

  void toggleComplete(String id) {
    final t = data.tasks.where((x) => x.id == id).firstOrNull;
    if (t == null) return;
    final completed = !t.completed;
    _patchLocal(id, (x) => x.copyWith(completed: completed, isPriority: completed ? false : x.isPriority));
    updateTask(id, {'completed': completed});
  }

  void toggleFrog(String id) {
    final t = data.tasks.where((x) => x.id == id).firstOrNull;
    if (t == null) return;
    final isPriority = !t.isPriority;
    _update(
      (d) => _copy(
        tasks:
            d.tasks
                .map(
                  (x) =>
                      x.id == id
                          ? x.copyWith(isPriority: isPriority)
                          : (isPriority && x.isPriority ? x.copyWith(isPriority: false) : x),
                )
                .toList(),
      ),
    );
    updateTask(id, {'isPriority': isPriority});
  }

  void clearFrog() {
    final flagged = data.tasks.where((t) => t.isPriority).toList();
    _update((d) => _copy(tasks: d.tasks.map((t) => t.isPriority ? t.copyWith(isPriority: false) : t).toList()));
    for (final t in flagged) {
      updateTask(t.id, {'isPriority': false});
    }
  }

  Future<bool> deleteTask(String id) async {
    final before = data.tasks;
    _update((d) => _copy(tasks: d.tasks.where((t) => t.id != id).toList()));
    try {
      await api.delete('/api/tasks/$id');
      return true;
    } catch (e) {
      _update((d) => _copy(tasks: before));
      await _fail(e);
      return false;
    }
  }

  Future<void> addSubtask(String taskId, String title) async {
    if (title.trim().isEmpty) return;
    try {
      final res = await api.post('/api/tasks/$taskId/subtasks', {'title': title.trim()});
      _putTask(Task.fromJson(res['task'] as Map<String, dynamic>));
    } catch (e) {
      await _fail(e);
    }
  }

  Future<void> updateSubtask(String taskId, String subId, {String? title, bool? completed}) async {
    _patchLocal(
      taskId,
      (t) => t.copyWith(
        subtasks: t.subtasks.map((s) => s.id == subId ? s.copyWith(title: title, completed: completed) : s).toList(),
      ),
    );
    try {
      final res = await api.patch('/api/tasks/$taskId/subtasks/$subId', {
        if (title != null) 'title': title,
        if (completed != null) 'completed': completed,
      });
      _putTask(Task.fromJson(res['task'] as Map<String, dynamic>));
      handleEvents(XpEvent.listFrom(res['events']));
    } catch (e) {
      await _fail(e);
      unawaited(refresh());
    }
  }

  Future<void> deleteSubtask(String taskId, String subId) async {
    _patchLocal(taskId, (t) => t.copyWith(subtasks: t.subtasks.where((s) => s.id != subId).toList()));
    try {
      final res = await api.delete('/api/tasks/$taskId/subtasks/$subId');
      _putTask(Task.fromJson(res['task'] as Map<String, dynamic>));
    } catch (e) {
      await _fail(e);
      unawaited(refresh());
    }
  }

  // ------------------------------------------------------------ goals

  Future<void> createGoal(String title, String color) async {
    try {
      final res = await api.post('/api/goals', {'title': title, 'color': color});
      _update((d) => _copy(goals: [...d.goals, Goal.fromJson(res['goal'] as Map<String, dynamic>)]));
      _toast('New Goal created!', ToastType.success);
    } catch (e) {
      await _fail(e);
    }
  }

  Future<void> updateGoal(String id, String title, String color) async {
    try {
      final res = await api.patch('/api/goals/$id', {'title': title, 'color': color});
      final goal = Goal.fromJson(res['goal'] as Map<String, dynamic>);
      _update((d) => _copy(goals: d.goals.map((g) => g.id == id ? goal : g).toList()));
      _toast('Goal updated', ToastType.success);
    } catch (e) {
      await _fail(e);
    }
  }

  Future<void> deleteGoal(String id) async {
    try {
      await api.delete('/api/goals/$id');
      if (activeGoalId == id) activeGoalId = null;
      _update(
        (d) => _copy(
          goals: d.goals.where((g) => g.id != id).toList(),
          tasks: d.tasks.map((t) => t.goalId == id ? t.copyWith(clearGoal: true) : t).toList(),
        ),
      );
    } catch (e) {
      await _fail(e);
    }
  }

  // ------------------------------------------------------------ account

  Future<String?> updateProfile({String? name, String? currentPassword, String? newPassword}) async {
    try {
      final res = await api.patch('/api/auth/me', {
        if (name != null) 'name': name,
        if (newPassword != null) 'currentPassword': currentPassword,
        if (newPassword != null) 'newPassword': newPassword,
      });
      final token = res['token'] as String?;
      if (token != null) {
        await Session.setToken(token);
        api.token = token;
      }
      _update((d) => _copy(user: User.fromJson(res['user'] as Map<String, dynamic>)));
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  void toast(String msg, [ToastType type = ToastType.normal]) => _toast(msg, type);
}
