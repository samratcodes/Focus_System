import 'package:flutter_test/flutter_test.dart';
import 'package:focus_system/logic.dart';
import 'package:focus_system/models.dart';

void main() {
  test('levels match the website (100 XP per level)', () {
    expect(levelInfo(0), (level: 1, xpInLevel: 0));
    expect(levelInfo(250), (level: 3, xpInLevel: 50));
  });

  test('fmtClock pads and clamps', () {
    expect(fmtClock(1500), '25:00');
    expect(fmtClock(61), '01:01');
    expect(fmtClock(-5), '00:00');
  });

  test('shiftDate crosses month and year boundaries', () {
    expect(shiftDate('2026-01-31', 1), '2026-02-01');
    expect(shiftDate('2026-01-01', -1), '2025-12-31');
  });

  test('streak counts consecutive days ending today', () {
    expect(streakCount(['2026-09-22', '2026-09-23', '2026-09-24'], '2026-09-24'), 3);
    expect(streakCount(['2026-09-20', '2026-09-24'], '2026-09-24'), 1);
    expect(streakCount(['2026-09-23'], '2026-09-24'), 0); // same rule as the website
    expect(streakCount([], '2026-09-24'), 0);
  });

  test('youtubeId parses the same links as the website', () {
    expect(youtubeId('https://youtu.be/jfKfPfyJRdk'), 'jfKfPfyJRdk');
    expect(youtubeId('https://www.youtube.com/watch?v=jfKfPfyJRdk&t=3'), 'jfKfPfyJRdk');
    expect(youtubeId('https://example.com'), '');
  });

  test('bootstrap JSON from the API parses', () {
    final b = Bootstrap.fromJson({
      'user': {
        'id': 'u1',
        'email': 'a@b.c',
        'name': 'A',
        'xp': 120,
        'timezone': 'UTC',
        'settings': {
          'pomoWork': 25,
          'pomoShortBreak': 5,
          'pomoLongBreak': 15,
          'pomoLongInterval': 4,
          'youtubeUrl': '',
          'alarmEnabled': true,
          'reminderMinutes': 10,
        },
      },
      'goals': [
        {'id': 'g1', 'title': 'Work', 'color': '#10B981', 'icon': 'target', 'sortOrder': 0},
      ],
      'tasks': [
        {
          'id': 't1',
          'goalId': 'g1',
          'title': 'Write',
          'description': '',
          'completed': false,
          'completedAt': null,
          'dueDate': '2026-09-24',
          'startTime': '09:00',
          'endTime': null,
          'eisenhower': 'do-first',
          'isPriority': true,
          'pomodoroCount': 2,
          'subtasks': [
            {'id': 's1', 'title': 'Outline', 'completed': true, 'sortOrder': 0},
          ],
          'createdAt': '2026-09-24T00:00:00.000Z',
          'updatedAt': '2026-09-24T00:00:00.000Z',
        },
      ],
      'pomoLogs': [
        {'id': 'p1', 'date': '2026-09-24', 'taskId': 't1', 'sessions': 2, 'minutes': 50},
      ],
      'streakDays': ['2026-09-24'],
      'focus': {
        'mode': 'work',
        'running': true,
        'endsAt': 1790000000000,
        'secondsLeft': 900,
        'totalSeconds': 1500,
        'sessionCount': 1,
        'attachedTaskId': 't1',
        'version': 3,
      },
      'events': [],
      'serverTime': 1789999100000,
      'today': '2026-09-24',
    });
    expect(b.tasks.single.subtasks.single.completed, isTrue);
    expect(b.focus.running, isTrue);
    expect(b.user.settings.phaseSeconds('shortBreak'), 300);
    expect(completionRate(b.tasks, '2026-09-24'), 0);
  });
}
