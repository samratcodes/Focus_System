// Pure helpers — ports of website/src/lib/shared/logic.ts.
import 'package:intl/intl.dart';

import 'models.dart';

const goalColors = ['#4F46E5', '#059669', '#D97706', '#DC2626', '#DB2777', '#7C3AED'];

String pad2(int n) => n.toString().padLeft(2, '0');

String toDateStr(DateTime d) => '${d.year}-${pad2(d.month)}-${pad2(d.day)}';

String todayStr() => toDateStr(DateTime.now());

DateTime parseDate(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String shiftDate(String date, int days) {
  final d = parseDate(date);
  return toDateStr(DateTime(d.year, d.month, d.day + days));
}

String fmtDate(String iso) => DateFormat('EEE, MMM d').format(parseDate(iso));
String fmtDateShort(String iso) => DateFormat('MMM d').format(parseDate(iso));

String fmtClock(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  return '${pad2(s ~/ 60)}:${pad2(s % 60)}';
}

int? timeToMinutes(String? t) {
  if (t == null || t.isEmpty) return null;
  final p = t.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

int nowMinutes() {
  final n = DateTime.now();
  return n.hour * 60 + n.minute;
}

String greeting(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 17) return 'Good afternoon';
  return 'Good evening';
}

({int level, int xpInLevel}) levelInfo(int xp) => (level: xp ~/ 100 + 1, xpInLevel: xp % 100);

String focusModeLabel(String mode) => switch (mode) {
  'work' => 'FOCUS',
  'shortBreak' => 'SHORT BREAK',
  _ => 'LONG BREAK',
};

const eisenhowerLabels = {
  'do-first': 'Do First',
  'schedule': 'Schedule',
  'delegate': 'Delegate',
  'eliminate': 'Eliminate',
};

String youtubeId(String? url) {
  if (url == null || url.isEmpty) return '';
  final m = RegExp(
    r'(?:youtube\.com\/(?:watch\?v=|embed\/|live\/|shorts\/)|youtu\.be\/)([A-Za-z0-9_-]{6,})',
  ).firstMatch(url);
  return m?.group(1) ?? '';
}

int streakCount(List<String> days, String today) {
  if (days.isEmpty) return 0;
  final sorted = [...days]..sort((a, b) => b.compareTo(a));
  final end = parseDate(today);
  var count = 0;
  for (final s in sorted) {
    // Rounded so DST shifts (23h/25h days) still count as one day.
    final d = (end.difference(parseDate(s)).inMinutes / 1440).round();
    if (d == count) {
      count++;
    } else if (d > count) {
      break;
    }
  }
  return count;
}

List<Task> tasksForDate(List<Task> tasks, String date) => tasks.where((t) => t.dueDate == date).toList();

int completionRate(List<Task> tasks, String date) {
  final list = tasksForDate(tasks, date);
  if (list.isEmpty) return 0;
  return (list.where((t) => t.completed).length / list.length * 100).round();
}
