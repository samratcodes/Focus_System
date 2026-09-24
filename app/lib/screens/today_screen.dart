import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../logic.dart';
import '../theme.dart';
import '../widgets/task_card.dart';
import '../widgets/ui.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final _title = TextEditingController();
  final _search = TextEditingController();
  String? _goalId;
  String? _time;
  String? _date;
  bool _priority = false;
  bool _adding = false;
  bool _searching = false;

  @override
  void dispose() {
    _title.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _quickAdd(AppState s) async {
    final title = _title.text.trim();
    if (title.isEmpty || _adding) return;
    final due = _date ?? s.today;
    if (due.compareTo(s.today) < 0) return s.toast('Cannot schedule tasks in the past', ToastType.error);
    if (_time != null && due == s.today && timeToMinutes(_time)! <= nowMinutes()) {
      return s.toast('Cannot schedule a past time for today', ToastType.error);
    }
    setState(() => _adding = true);
    final created = await s.createTask({
      'title': title,
      'goalId': _goalId ?? s.activeGoalId,
      'dueDate': due,
      'startTime': _time,
      'isPriority': _priority,
    });
    if (!mounted) return;
    setState(() {
      _adding = false;
      if (created != null) {
        _title.clear();
        _priority = false;
        _time = null;
      }
    });
    if (created != null) s.toast('Task added', ToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final d = s.data;
    final today = s.today;

    var tasks = tasksForDate(d.tasks, today);
    if (s.activeGoalId != null) tasks = tasks.where((t) => t.goalId == s.activeGoalId).toList();
    if (s.searchQuery.isNotEmpty) {
      final q = s.searchQuery.toLowerCase();
      tasks = tasks.where((t) => t.title.toLowerCase().contains(q)).toList();
    }
    final open = tasks.where((t) => !t.completed).toList();
    final doneTasks = tasks.where((t) => t.completed).toList();
    final allToday = tasksForDate(d.tasks, today);
    final done = allToday.where((t) => t.completed).length;
    final total = allToday.length;
    final frog = d.tasks.where((t) => t.isPriority && !t.completed && t.dueDate == today).firstOrNull;

    return Column(
      children: [
        AppHeader(
          trailing: IconBtn(
            _searching ? LucideIcons.x : LucideIcons.search,
            tooltip: 'Search tasks',
            onPressed:
                () => setState(() {
                  _searching = !_searching;
                  if (!_searching) {
                    _search.clear();
                    s.setUi(() => s.searchQuery = '');
                  }
                }),
          ),
        ),
        if (_searching)
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _search,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search tasks...',
                prefixIcon: Icon(LucideIcons.search, size: 16, color: AppColors.textMuted),
              ),
              onChanged: (v) => s.setUi(() => s.searchQuery = v),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: s.refresh,
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                // .daily-board
                Panel(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(fmtDate(today), style: AppText.label),
                                const SizedBox(height: 4),
                                const Text('Plan today. Do one thing at a time.', style: AppText.h1),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          DailyScore(done: done, total: total),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ProgressTrack(value: total == 0 ? 0 : done / total),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _WeekStrip(today: today),
                const SizedBox(height: 14),
                // Step 1
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Kicker('Step 1'),
                      const SizedBox(height: 4),
                      const Text('Pick the main task', style: AppText.h2),
                      if (frog != null)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(AppRadius.panel),
                            border: const Border(
                              left: BorderSide(color: AppColors.frog, width: 3),
                              top: BorderSide(color: AppColors.border),
                              right: BorderSide(color: AppColors.border),
                              bottom: BorderSide(color: AppColors.border),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Kicker('Priority', color: AppColors.frog),
                                    const SizedBox(height: 2),
                                    Text(frog.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              Btn(label: 'Done', icon: LucideIcons.check, onPressed: () => s.toggleComplete(frog.id)),
                              const SizedBox(width: 6),
                              Btn(label: 'Clear', kind: BtnKind.ghost, onPressed: s.clearFrog),
                            ],
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            'Choose one task with the bolt button. This keeps today clear and focused.',
                            style: AppText.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Step 2
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Kicker('Step 2'),
                      const SizedBox(height: 4),
                      const Text('Add the next action', style: AppText.h2),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _title,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(hintText: 'Write one clear action...'),
                              onSubmitted: (_) => _quickAdd(s),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Btn(label: 'Add', icon: LucideIcons.plus, busy: _adding, onPressed: () => _quickAdd(s)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _goalPicker(s),
                          PickerChip(
                            icon: LucideIcons.clock,
                            label: _time ?? '--:--',
                            onTap: () async {
                              final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                              if (t != null) setState(() => _time = '${pad2(t.hour)}:${pad2(t.minute)}');
                            },
                            onClear: _time == null ? null : () => setState(() => _time = null),
                          ),
                          PickerChip(
                            icon: LucideIcons.calendar,
                            label: fmtDateShort(_date ?? today),
                            onTap: () async {
                              final first = parseDate(today);
                              final p = await showDatePicker(
                                context: context,
                                firstDate: first,
                                lastDate: DateTime(first.year + 5),
                                initialDate: parseDate(_date ?? today),
                              );
                              if (p != null) setState(() => _date = toDateStr(p));
                            },
                          ),
                          InkWell(
                            onTap: () => setState(() => _priority = !_priority),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 30,
                                  child: Checkbox(
                                    value: _priority,
                                    activeColor: AppColors.frog,
                                    onChanged: (v) => setState(() => _priority = v ?? false),
                                  ),
                                ),
                                const Text(
                                  'Priority',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _GoalPills(),
                const SizedBox(height: 14),
                const SectionTitle(kicker: 'Step 3', title: 'Do these today'),
                const SizedBox(height: 10),
                if (open.isEmpty)
                  EmptyState(
                    icon: LucideIcons.clipboardList,
                    title: s.searchQuery.isEmpty ? 'Your list is clear' : 'No matching tasks',
                    message:
                        s.searchQuery.isEmpty
                            ? 'Add one action above, or enjoy the clean slate.'
                            : 'Try a different search.',
                  )
                else
                  for (final t in open)
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: TaskCard(key: ValueKey(t.id), task: t)),
                if (doneTasks.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Opacity(opacity: 0.82, child: const SectionTitle(kicker: 'Done', title: 'Completed today')),
                  const SizedBox(height: 10),
                  for (final t in doneTasks)
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: TaskCard(key: ValueKey(t.id), task: t)),
                ],
                const SizedBox(height: 70),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _goalPicker(AppState s) {
    final goals = s.data.goals;
    final value = _goalId ?? s.activeGoalId;
    final goal = goals.where((g) => g.id == value).firstOrNull;
    return PopupMenuButton<String>(
      color: AppColors.surface2,
      onSelected: (v) => setState(() => _goalId = v.isEmpty ? null : v),
      itemBuilder:
          (_) => [
            const PopupMenuItem(value: '', child: Text('No goal')),
            for (final g in goals) PopupMenuItem(value: g.id, child: Text(g.title)),
          ],
      child: IgnorePointer(child: PickerChip(icon: LucideIcons.target, label: goal?.title ?? 'No goal', onTap: () {})),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.today});
  final String today;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final ds = shiftDate(today, i);
          final date = parseDate(ds);
          final list = tasksForDate(s.data.tasks, ds);
          final dayDone = list.where((t) => t.completed).length;
          final rate = list.isEmpty ? 0.0 : dayDone / list.length;
          const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          return GestureDetector(
            onTap:
                () => s.setUi(() {
                  s.selectedDate = ds;
                  s.calendarMonth = date.month;
                  s.calendarYear = date.year;
                  s.tab = 1;
                }),
            child: Container(
              width: 76,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.panel),
                border: Border.all(color: i == 0 ? AppColors.primary : AppColors.border),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 92 * (rate < 0.04 ? 0.04 : rate),
                    child: Container(color: AppColors.success.withValues(alpha: 0.28)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          names[date.weekday - 1],
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${date.day}',
                          style: const TextStyle(fontSize: 22, height: 1.1, fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        Text(
                          '$dayDone/${list.length}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GoalPills extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    Future<void> create() async {
      final r = await goalDialog(context, title: 'New goal', submitLabel: 'Create goal');
      if (r != null) await s.createGoal(r.name, r.color);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Kicker('View'),
            const Spacer(),
            Btn(label: 'Goal', icon: LucideIcons.plus, kind: BtnKind.secondary, small: true, onPressed: create),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _pill(
                selected: s.activeGoalId == null,
                color: AppColors.primary,
                onTap: () => s.setUi(() => s.activeGoalId = null),
                child: const Text('All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              for (final g in s.data.goals)
                _pill(
                  selected: s.activeGoalId == g.id,
                  color: AppColors.parse(g.color),
                  onTap: () => s.setUi(() => s.activeGoalId = g.id),
                  onLongPress: () => _goalMenu(context, s, g.id),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: AppColors.parse(g.color), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(g.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 2),
                      GestureDetector(
                        onTap: () => _goalMenu(context, s, g.id),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(LucideIcons.pencil, size: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pill({
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    required Widget child,
  }) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Semantics(
      container: true,
      button: true,
      selected: selected,
      child: Material(
        color: selected ? color.withValues(alpha: 0.13) : AppColors.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? color : AppColors.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: selected ? color : AppColors.textSecondary),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _goalMenu(BuildContext context, AppState s, String goalId) async {
    final g = s.data.goals.firstWhere((x) => x.id == goalId);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.pencil, size: 18),
                  title: Text('Edit "${g.title}"'),
                  onTap: () => Navigator.pop(ctx, 'edit'),
                ),
                ListTile(
                  leading: const Icon(LucideIcons.trash2, size: 18, color: AppColors.danger),
                  title: const Text('Delete goal', style: TextStyle(color: AppColors.danger)),
                  onTap: () => Navigator.pop(ctx, 'delete'),
                ),
              ],
            ),
          ),
    );
    if (!context.mounted) return;
    if (action == 'edit') {
      final r = await goalDialog(context, title: 'Edit goal', initialName: g.title, initialColor: g.color);
      if (r != null) await s.updateGoal(g.id, r.name, r.color);
    } else if (action == 'delete') {
      final ok = await confirmDialog(
        context,
        title: 'Delete "${g.title}"?',
        message: 'Tasks in this goal will become uncategorized.',
        confirmLabel: 'Delete goal',
        danger: true,
      );
      if (ok) await s.deleteGoal(g.id);
    }
  }
}
