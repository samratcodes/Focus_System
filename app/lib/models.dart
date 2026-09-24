// Mirrors website/src/lib/shared/types.ts (the API contract).

class Subtask {
  final String id;
  final String title;
  final bool completed;
  final int sortOrder;

  const Subtask({required this.id, required this.title, required this.completed, this.sortOrder = 0});

  factory Subtask.fromJson(Map<String, dynamic> j) => Subtask(
    id: j['id'] as String,
    title: j['title'] as String,
    completed: j['completed'] as bool? ?? false,
    sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
  );

  Subtask copyWith({String? title, bool? completed}) =>
      Subtask(id: id, title: title ?? this.title, completed: completed ?? this.completed, sortOrder: sortOrder);
}

class Task {
  final String id;
  final String? goalId;
  final String title;
  final String description;
  final bool completed;
  final String dueDate;
  final String? startTime;
  final String? endTime;
  final String? eisenhower;
  final bool isPriority;
  final int pomodoroCount;
  final List<Subtask> subtasks;

  const Task({
    required this.id,
    required this.goalId,
    required this.title,
    required this.description,
    required this.completed,
    required this.dueDate,
    required this.startTime,
    required this.endTime,
    required this.eisenhower,
    required this.isPriority,
    required this.pomodoroCount,
    required this.subtasks,
  });

  factory Task.fromJson(Map<String, dynamic> j) => Task(
    id: j['id'] as String,
    goalId: j['goalId'] as String?,
    title: j['title'] as String,
    description: j['description'] as String? ?? '',
    completed: j['completed'] as bool? ?? false,
    dueDate: j['dueDate'] as String,
    startTime: j['startTime'] as String?,
    endTime: j['endTime'] as String?,
    eisenhower: j['eisenhower'] as String?,
    isPriority: j['isPriority'] as bool? ?? false,
    pomodoroCount: (j['pomodoroCount'] as num?)?.toInt() ?? 0,
    subtasks: ((j['subtasks'] as List?) ?? const []).map((s) => Subtask.fromJson(s as Map<String, dynamic>)).toList(),
  );

  Task copyWith({bool? completed, bool? isPriority, String? goalId, bool clearGoal = false, List<Subtask>? subtasks}) =>
      Task(
        id: id,
        goalId: clearGoal ? null : (goalId ?? this.goalId),
        title: title,
        description: description,
        completed: completed ?? this.completed,
        dueDate: dueDate,
        startTime: startTime,
        endTime: endTime,
        eisenhower: eisenhower,
        isPriority: isPriority ?? this.isPriority,
        pomodoroCount: pomodoroCount,
        subtasks: subtasks ?? this.subtasks,
      );
}

class Goal {
  final String id;
  final String title;
  final String color;
  final String icon;

  const Goal({required this.id, required this.title, required this.color, required this.icon});

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
    id: j['id'] as String,
    title: j['title'] as String,
    color: j['color'] as String? ?? '#6366F1',
    icon: j['icon'] as String? ?? 'target',
  );
}

class UserSettings {
  final int pomoWork;
  final int pomoShortBreak;
  final int pomoLongBreak;
  final int pomoLongInterval;
  final String youtubeUrl;
  final bool alarmEnabled;
  final int reminderMinutes;

  const UserSettings({
    required this.pomoWork,
    required this.pomoShortBreak,
    required this.pomoLongBreak,
    required this.pomoLongInterval,
    required this.youtubeUrl,
    required this.alarmEnabled,
    required this.reminderMinutes,
  });

  factory UserSettings.fromJson(Map<String, dynamic> j) => UserSettings(
    pomoWork: (j['pomoWork'] as num?)?.toInt() ?? 25,
    pomoShortBreak: (j['pomoShortBreak'] as num?)?.toInt() ?? 5,
    pomoLongBreak: (j['pomoLongBreak'] as num?)?.toInt() ?? 15,
    pomoLongInterval: (j['pomoLongInterval'] as num?)?.toInt() ?? 4,
    youtubeUrl: j['youtubeUrl'] as String? ?? '',
    alarmEnabled: j['alarmEnabled'] as bool? ?? true,
    reminderMinutes: (j['reminderMinutes'] as num?)?.toInt() ?? 10,
  );

  int phaseSeconds(String mode) => switch (mode) {
    'shortBreak' => pomoShortBreak * 60,
    'longBreak' => pomoLongBreak * 60,
    _ => pomoWork * 60,
  };
}

class User {
  final String id;
  final String email;
  final String name;
  final int xp;
  final String timezone;
  final UserSettings settings;

  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.xp,
    required this.timezone,
    required this.settings,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id'] as String,
    email: j['email'] as String,
    name: j['name'] as String,
    xp: (j['xp'] as num?)?.toInt() ?? 0,
    timezone: j['timezone'] as String? ?? 'UTC',
    settings: UserSettings.fromJson(j['settings'] as Map<String, dynamic>),
  );

  User copyWith({int? xp, String? name}) =>
      User(id: id, email: email, name: name ?? this.name, xp: xp ?? this.xp, timezone: timezone, settings: settings);
}

class PomoLog {
  final String id;
  final String date;
  final String? taskId;
  final int sessions;
  final int minutes;

  const PomoLog({required this.id, required this.date, this.taskId, required this.sessions, required this.minutes});

  factory PomoLog.fromJson(Map<String, dynamic> j) => PomoLog(
    id: j['id'] as String,
    date: j['date'] as String,
    taskId: j['taskId'] as String?,
    sessions: (j['sessions'] as num?)?.toInt() ?? 1,
    minutes: (j['minutes'] as num?)?.toInt() ?? 0,
  );
}

class FocusState {
  final String mode; // work | shortBreak | longBreak
  final bool running;
  final int? endsAt; // epoch ms (server clock)
  final int secondsLeft;
  final int totalSeconds;
  final int sessionCount;
  final String? attachedTaskId;
  final int version;

  const FocusState({
    required this.mode,
    required this.running,
    required this.endsAt,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.sessionCount,
    required this.attachedTaskId,
    required this.version,
  });

  factory FocusState.fromJson(Map<String, dynamic> j) => FocusState(
    mode: j['mode'] as String? ?? 'work',
    running: j['running'] as bool? ?? false,
    endsAt: (j['endsAt'] as num?)?.toInt(),
    secondsLeft: (j['secondsLeft'] as num?)?.toInt() ?? 1500,
    totalSeconds: (j['totalSeconds'] as num?)?.toInt() ?? 1500,
    sessionCount: (j['sessionCount'] as num?)?.toInt() ?? 0,
    attachedTaskId: j['attachedTaskId'] as String?,
    version: (j['version'] as num?)?.toInt() ?? 0,
  );

  FocusState withAttached(String? taskId) => FocusState(
    mode: mode,
    running: running,
    endsAt: endsAt,
    secondsLeft: secondsLeft,
    totalSeconds: totalSeconds,
    sessionCount: sessionCount,
    attachedTaskId: taskId,
    version: version,
  );
}

class XpEvent {
  final int amount;
  final String reason;
  final int total;
  final int level;
  final bool leveledUp;

  const XpEvent({
    required this.amount,
    required this.reason,
    required this.total,
    required this.level,
    required this.leveledUp,
  });

  factory XpEvent.fromJson(Map<String, dynamic> j) => XpEvent(
    amount: (j['amount'] as num).toInt(),
    reason: j['reason'] as String? ?? '',
    total: (j['total'] as num).toInt(),
    level: (j['level'] as num).toInt(),
    leveledUp: j['leveledUp'] as bool? ?? false,
  );

  static List<XpEvent> listFrom(dynamic v) =>
      ((v as List?) ?? const []).map((e) => XpEvent.fromJson(e as Map<String, dynamic>)).toList();
}

class Bootstrap {
  final User user;
  final List<Goal> goals;
  final List<Task> tasks;
  final List<PomoLog> pomoLogs;
  final List<String> streakDays;
  final FocusState focus;
  final List<XpEvent> events;
  final int serverTime;

  const Bootstrap({
    required this.user,
    required this.goals,
    required this.tasks,
    required this.pomoLogs,
    required this.streakDays,
    required this.focus,
    required this.events,
    required this.serverTime,
  });

  factory Bootstrap.fromJson(Map<String, dynamic> j) => Bootstrap(
    user: User.fromJson(j['user'] as Map<String, dynamic>),
    goals: (j['goals'] as List).map((e) => Goal.fromJson(e as Map<String, dynamic>)).toList(),
    tasks: (j['tasks'] as List).map((e) => Task.fromJson(e as Map<String, dynamic>)).toList(),
    pomoLogs: (j['pomoLogs'] as List).map((e) => PomoLog.fromJson(e as Map<String, dynamic>)).toList(),
    streakDays: (j['streakDays'] as List).cast<String>(),
    focus: FocusState.fromJson(j['focus'] as Map<String, dynamic>),
    events: XpEvent.listFrom(j['events']),
    serverTime: (j['serverTime'] as num).toInt(),
  );
}
