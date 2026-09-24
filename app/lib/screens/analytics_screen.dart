import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../logic.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/ui.dart';

List<String> _periodDays(String today, String period) {
  final count = period == 'day' ? 1 : (period == 'month' ? 30 : 7);
  return [for (var i = count - 1; i >= 0; i--) shiftDate(today, -i)];
}

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final d = s.data;
    final today = s.today;
    final period = s.analyticsPeriod;
    final days = _periodDays(today, period);
    final daySet = days.toSet();
    final tasks = d.tasks.where((t) => daySet.contains(t.dueDate)).toList();
    final done = tasks.where((t) => t.completed).length;
    final rate = tasks.isEmpty ? 0 : (done / tasks.length * 100).round();
    final logs = d.pomoLogs.where((l) => daySet.contains(l.date));
    final sessions = logs.fold<int>(0, (a, l) => a + l.sessions);
    final minutes = logs.fold<int>(
      0,
      (a, l) => a + (l.minutes > 0 ? l.minutes : l.sessions * d.user.settings.pomoWork),
    );
    final best =
        days
            .map((ds) => (date: ds, done: tasksForDate(d.tasks, ds).where((t) => t.completed).length))
            .fold<({String date, int done})?>(null, (b, x) => b == null || x.done > b.done ? x : b)!;
    final avg = (done / days.length * 10).round() / 10;
    final label = period == 'day' ? 'Today' : (period == 'week' ? 'Last 7 days' : 'Last 30 days');

    return Column(
      children: [
        const AppHeader(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: s.refresh,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Panel(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppText.label),
                      const SizedBox(height: 4),
                      const Text('Performance dashboard', style: AppText.h1),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(AppRadius.panel),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final p in const ['day', 'week', 'month'])
                              GestureDetector(
                                onTap: () => s.setUi(() => s.analyticsPeriod = p),
                                child: Container(
                                  width: 72,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: period == p ? AppColors.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: Text(
                                    p[0].toUpperCase() + p.substring(1),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: period == p ? Colors.white : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    _Metric('Completion', '$rate%', '$done of ${tasks.length} tasks'),
                    _Metric('Daily average', '$avg', 'completed tasks'),
                    _Metric('Focus time', '${minutes}m', '$sessions sessions'),
                    _Metric('Best day', '${best.done}', fmtDateShort(best.date)),
                  ],
                ),
                const SizedBox(height: 16),
                _Card(title: 'Day by day results', child: _Trend(days: days)),
                const SizedBox(height: 16),
                _Card(title: 'By goal/category', child: _GoalBreakdown(tasks: tasks)),
                const SizedBox(height: 16),
                _Card(title: 'Task type', child: _Matrix(tasks: tasks)),
                const SizedBox(height: 16),
                _Card(title: 'Streak', child: _Streak(today: today)),
                const SizedBox(height: 16),
                _Card(title: 'Level', child: _Level(xp: d.user.xp)),
                const SizedBox(height: 70),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.caption);
  final String label;
  final String value;
  final String caption;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            height: 1,
            fontWeight: FontWeight.w900,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Kicker(title), const SizedBox(height: 12), child],
    ),
  );
}

class _Trend extends StatelessWidget {
  const _Trend({required this.days});
  final List<String> days;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    Widget bar(String ds) {
      final list = tasksForDate(s.data.tasks, ds);
      final d = list.where((t) => t.completed).length;
      final r = list.isEmpty ? 0 : (d / list.length * 100).round();
      final color = r >= 80 ? AppColors.success : (r >= 40 ? AppColors.primary : AppColors.warning);
      return SizedBox(
        width: 46,
        child: Column(
          children: [
            Container(
              height: 132,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadius.panel),
                border: Border.all(color: AppColors.border),
              ),
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: (r < 6 ? 6 : r) / 100,
                widthFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.panel)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text('$r%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            Text(
              fmtDateShort(ds),
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w800),
            ),
            Text(
              '$d/${list.length}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true, // most recent day visible first
      child: Row(children: [for (final ds in days) Padding(padding: const EdgeInsets.only(right: 10), child: bar(ds))]),
    );
  }
}

class _GoalBreakdown extends StatelessWidget {
  const _GoalBreakdown({required this.tasks});
  final List<Task> tasks;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final rows = <({String title, Color color, int total, int done})>[];
    for (final g in s.data.goals) {
      final gt = tasks.where((t) => t.goalId == g.id).toList();
      if (gt.isNotEmpty) {
        rows.add((
          title: g.title,
          color: AppColors.parse(g.color),
          total: gt.length,
          done: gt.where((t) => t.completed).length,
        ));
      }
    }
    final none = tasks.where((t) => t.goalId == null).toList();
    if (none.isNotEmpty) {
      rows.add((
        title: 'No goal',
        color: AppColors.textMuted,
        total: none.length,
        done: none.where((t) => t.completed).length,
      ));
    }
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No category data yet.', style: TextStyle(color: AppColors.textMuted))),
      );
    }
    return Column(
      children: [
        for (final r in rows)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.panel),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: r.color, shape: BoxShape.circle)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        r.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${r.done}/${r.total} complete',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${(r.done / r.total * 100).round()}%',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ProgressTrack(value: r.done / r.total, color: r.color),
              ],
            ),
          ),
      ],
    );
  }
}

class _Matrix extends StatelessWidget {
  const _Matrix({required this.tasks});
  final List<Task> tasks;
  @override
  Widget build(BuildContext context) {
    final open = tasks.where((t) => !t.completed);
    const cells = [
      ('do-first', 'Do First', AppColors.danger, AppColors.dangerBg),
      ('schedule', 'Schedule', AppColors.info, AppColors.infoBg),
      ('delegate', 'Delegate', AppColors.warning, AppColors.warningBg),
      ('eliminate', 'Eliminate', AppColors.textMuted, AppColors.surface3),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.9,
      children: [
        for (final (key, label, fg, bg) in cells)
          Container(
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.sm)),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${open.where((t) => t.eisenhower == key).length}',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: fg),
                ),
                Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: 0.4)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Streak extends StatelessWidget {
  const _Streak({required this.today});
  final String today;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final days = _periodDays(today, 'month');
    final active = s.data.streakDays.toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${streakCount(s.data.streakDays, today)}',
              style: const TextStyle(fontSize: 48, height: 1, fontWeight: FontWeight.w900, color: AppColors.frog),
            ),
            const SizedBox(width: 12),
            const Text('days in a row\nwith activity', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final ds in days)
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: active.contains(ds) ? AppColors.success : AppColors.surface3,
                  borderRadius: BorderRadius.circular(2),
                  border: ds == today ? Border.all(color: AppColors.primary, width: 2) : null,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Level extends StatelessWidget {
  const _Level({required this.xp});
  final int xp;
  @override
  Widget build(BuildContext context) {
    final l = levelInfo(xp);
    return Column(
      children: [
        Row(
          children: [
            Text(
              '${l.level}',
              style: const TextStyle(fontSize: 48, height: 1, fontWeight: FontWeight.w900, color: AppColors.xpGold),
            ),
            const SizedBox(width: 12),
            Text(
              '$xp XP total\n${100 - l.xpInLevel} XP to level ${l.level + 1}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ProgressTrack(value: l.xpInLevel / 100, color: AppColors.xpGold),
      ],
    );
  }
}
