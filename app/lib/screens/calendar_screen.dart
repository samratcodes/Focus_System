import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../logic.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/task_card.dart';
import '../widgets/ui.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final today = s.today;
    final selected = s.selectedDate;
    final selectedTasks = tasksForDate(s.data.tasks, selected);
    final active = selectedTasks.where((t) => !t.completed).toList();
    final completed = selectedTasks.where((t) => t.completed).toList();
    final total = selectedTasks.length;

    void selectDate(String ds) {
      final d = parseDate(ds);
      s.setUi(() {
        s.selectedDate = ds;
        s.calendarMonth = d.month;
        s.calendarYear = d.year;
      });
    }

    void navMonth(int dir) => s.setUi(() {
      var m = s.calendarMonth + dir;
      var y = s.calendarYear;
      if (m < 1) {
        m = 12;
        y--;
      }
      if (m > 12) {
        m = 1;
        y++;
      }
      s.calendarMonth = m;
      s.calendarYear = y;
    });

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
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Calendar', style: AppText.label),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    DateFormat('MMMM y').format(DateTime(s.calendarYear, s.calendarMonth)),
                                    maxLines: 1,
                                    style: AppText.h1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _navBtn(LucideIcons.chevronLeft, () => navMonth(-1)),
                          const SizedBox(width: 6),
                          Btn(label: 'Today', kind: BtnKind.secondary, onPressed: () => selectDate(today)),
                          const SizedBox(width: 6),
                          _navBtn(LucideIcons.chevronRight, () => navMonth(1)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _MonthGrid(onSelect: selectDate),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Selected date', style: AppText.label),
                                Text(
                                  fmtDate(selected),
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                          DailyScore(done: completed.length, total: total, small: true),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ProgressTrack(value: total == 0 ? 0 : completed.length / total),
                      const SizedBox(height: 14),
                      if (selected.compareTo(today) < 0)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(AppRadius.panel),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            children: [
                              Icon(LucideIcons.lock, size: 17, color: AppColors.warning),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Past dates are read-only. Pick today or a future date to add tasks.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        _DayComposer(key: ValueKey(selected), date: selected),
                      const SizedBox(height: 14),
                      SectionTitle(kicker: 'Tasks', title: '${active.length} active'),
                      const SizedBox(height: 10),
                      if (active.isEmpty)
                        EmptyState(
                          compact: true,
                          icon: LucideIcons.calendarPlus,
                          title: total == 0 ? 'Nothing planned' : 'All clear',
                          message:
                              total == 0
                                  ? 'Add one task above for this date.'
                                  : 'Every task for this date is completed.',
                        )
                      else
                        for (final t in active)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TaskCard(key: ValueKey(t.id), task: t),
                          ),
                      if (completed.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        SectionTitle(kicker: 'Done', title: '${completed.length} completed'),
                        const SizedBox(height: 10),
                        for (final t in completed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TaskCard(key: ValueKey(t.id), task: t),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 70),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) => Btn(
    label: '',
    icon: icon,
    kind: BtnKind.secondary,
    onPressed: onTap,
    semanticLabel: icon == LucideIcons.chevronLeft ? 'Previous month' : 'Next month',
  );
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.onSelect});
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final y = s.calendarYear;
    final m = s.calendarMonth;
    final firstWeekday = DateTime(y, m, 1).weekday % 7; // Sunday = 0 (like the web)
    final daysInMonth = DateTime(y, m + 1, 0).day;
    final cells = <(int, String, bool)>[];
    for (var i = firstWeekday - 1; i >= 0; i--) {
      final d = DateTime(y, m, -i);
      cells.add((d.day, toDateStr(d), true));
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add((d, toDateStr(DateTime(y, m, d)), false));
    }
    for (var n = 1; cells.length < 42; n++) {
      cells.add((n, toDateStr(DateTime(y, m + 1, n)), true));
    }

    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.panel),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.border,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.panel),
        ),
        child: Column(
          children: [
            Row(
              children: [
                for (final n in names)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(0.5),
                      color: AppColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      child: Text(
                        n.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            for (var row = 0; row < 6; row++)
              Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(child: _DayCell(cell: cells[row * 7 + col], onSelect: onSelect)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.cell, required this.onSelect});
  final (int, String, bool) cell;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final (day, date, other) = cell;
    final tasks = tasksForDate(s.data.tasks, date);
    final done = tasks.where((t) => t.completed).length;
    final priority = tasks.any((t) => t.isPriority && !t.completed);
    final isToday = date == s.today;
    final isSelected = date == s.selectedDate;
    final past = date.compareTo(s.today) < 0 && !other;

    Color dotColor(Task t) => t.completed ? AppColors.success : (t.isPriority ? AppColors.frog : AppColors.textMuted);

    return Opacity(
      opacity: past ? 0.3 : (other ? 0.42 : 1),
      child: GestureDetector(
        onTap: () => onSelect(date),
        child: Container(
          margin: const EdgeInsets.all(0.5),
          height: 64,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: isToday && !isSelected ? null : (isSelected || past ? AppColors.surface2 : AppColors.surface),
            gradient:
                isToday && !isSelected
                    ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.primaryBg, AppColors.surface],
                    )
                    : null,
            border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
          ),
          child: Stack(
            children: [
              Text('$day', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              Positioned(
                left: 0,
                top: 20,
                child: Row(
                  children: [
                    for (final t in tasks.take(4))
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(color: dotColor(t), shape: BoxShape.circle),
                      ),
                  ],
                ),
              ),
              if (tasks.isNotEmpty)
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Text(
                    '$done/${tasks.length}',
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w800),
                  ),
                ),
              if (priority)
                const Positioned(right: 0, bottom: 0, child: Icon(LucideIcons.zap, size: 11, color: AppColors.frog)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayComposer extends StatefulWidget {
  const _DayComposer({super.key, required this.date});
  final String date;
  @override
  State<_DayComposer> createState() => _DayComposerState();
}

class _DayComposerState extends State<_DayComposer> {
  final _title = TextEditingController();
  String? _goalId;
  String? _time;
  bool _priority = false;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final s = context.read<AppState>();
    if (_title.text.trim().isEmpty || _busy) return;
    if (_time != null && widget.date == s.today && timeToMinutes(_time)! <= nowMinutes()) {
      return s.toast('Cannot schedule a past time for today', ToastType.error);
    }
    setState(() => _busy = true);
    final created = await s.createTask({
      'title': _title.text.trim(),
      'goalId': _goalId,
      'dueDate': widget.date,
      'startTime': _time,
      'isPriority': _priority,
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (created != null) {
        _title.clear();
        _priority = false;
        _time = null;
      }
    });
    if (created != null) s.toast('Task added for ${fmtDateShort(widget.date)}', ToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final goal = s.data.goals.where((g) => g.id == _goalId).firstOrNull;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Add a task for ${fmtDateShort(widget.date)}...',
              fillColor: AppColors.surface,
            ),
            onSubmitted: (_) => _add(),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PopupMenuButton<String>(
                color: AppColors.surface2,
                onSelected: (v) => setState(() => _goalId = v.isEmpty ? null : v),
                itemBuilder:
                    (_) => [
                      const PopupMenuItem(value: '', child: Text('No goal')),
                      for (final g in s.data.goals) PopupMenuItem(value: g.id, child: Text(g.title)),
                    ],
                child: IgnorePointer(
                  child: PickerChip(icon: LucideIcons.target, label: goal?.title ?? 'No goal', onTap: () {}),
                ),
              ),
              PickerChip(
                icon: LucideIcons.clock,
                label: _time ?? '--:--',
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                  if (t != null) setState(() => _time = '${pad2(t.hour)}:${pad2(t.minute)}');
                },
                onClear: _time == null ? null : () => setState(() => _time = null),
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
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Btn(label: 'Add', icon: LucideIcons.plus, busy: _busy, onPressed: _add),
            ],
          ),
        ],
      ),
    );
  }
}
