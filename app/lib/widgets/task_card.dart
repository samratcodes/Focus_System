import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../logic.dart';
import '../models.dart';
import '../theme.dart';
import 'task_editor.dart';
import 'ui.dart';

class TaskCard extends StatefulWidget {
  const TaskCard({super.key, required this.task});
  final Task task;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  final _sub = TextEditingController();

  @override
  void dispose() {
    _sub.dispose();
    super.dispose();
  }

  Future<void> _delete(AppState s) async {
    if (await confirmDialog(context, title: 'Delete this task?', confirmLabel: 'Delete', danger: true)) {
      await s.deleteTask(widget.task.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final t = widget.task;
    final goal = t.goalId == null ? null : s.data.goals.where((g) => g.id == t.goalId).firstOrNull;
    final doneSubs = t.subtasks.where((x) => x.completed).length;

    const metaStyle = TextStyle(fontSize: 11, color: AppColors.textMuted);
    Widget meta(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(text, style: metaStyle),
      ],
    );

    final eisColors = {
      'do-first': (AppColors.danger, AppColors.dangerBg),
      'schedule': (AppColors.info, AppColors.infoBg),
      'delegate': (AppColors.warning, AppColors.warningBg),
      'eliminate': (AppColors.textMuted, AppColors.surface3),
    };

    return Opacity(
      opacity: t.completed ? 0.45 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => s.toggleComplete(t.id),
              child: Container(
                margin: const EdgeInsets.only(top: 1),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.completed ? AppColors.success : Colors.transparent,
                  border: Border.all(color: t.completed ? AppColors.success : AppColors.textMuted, width: 2),
                ),
                child: t.completed ? const Icon(LucideIcons.check, size: 13, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showTaskEditor(context, task: t),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: t.completed ? TextDecoration.lineThrough : null,
                        color: t.completed ? AppColors.textMuted : AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (goal != null)
                          Pill(
                            '🎯 ${goal.title}',
                            fg: AppColors.parse(goal.color),
                            bg: AppColors.parse(goal.color).withValues(alpha: 0.13),
                            border: AppColors.parse(goal.color).withValues(alpha: 0.27),
                          ),
                        if (t.isPriority) const Pill('Priority', fg: AppColors.frog, bg: AppColors.frogBg),
                        if (t.dueDate == s.today) const Pill('Today', fg: AppColors.primary, bg: AppColors.primaryBg),
                        if (t.eisenhower != null && eisColors.containsKey(t.eisenhower))
                          Pill(
                            eisenhowerLabels[t.eisenhower]!,
                            fg: eisColors[t.eisenhower]!.$1,
                            bg: eisColors[t.eisenhower]!.$2,
                          ),
                        if (t.startTime != null)
                          meta(LucideIcons.clock, t.endTime != null ? '${t.startTime} - ${t.endTime}' : t.startTime!),
                        if (t.subtasks.isNotEmpty) meta(LucideIcons.listChecks, '$doneSubs/${t.subtasks.length}'),
                        if (t.pomodoroCount > 0) meta(LucideIcons.timer, '${t.pomodoroCount}'),
                      ],
                    ),
                    if (t.subtasks.isNotEmpty) _subtasks(s, t),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                IconBtn(LucideIcons.pencil, tooltip: 'Edit', onPressed: () => showTaskEditor(context, task: t)),
                IconBtn(
                  LucideIcons.zap,
                  tooltip: t.isPriority ? 'Unmark priority' : 'Make priority',
                  color: t.isPriority ? AppColors.frog : null,
                  onPressed: () => s.toggleFrog(t.id),
                ),
                IconBtn(LucideIcons.trash2, tooltip: 'Delete', onPressed: () => _delete(s)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _subtasks(AppState s, Task t) {
    void add() {
      final text = _sub.text;
      _sub.clear();
      s.addSubtask(t.id, text);
    }

    return Container(
      margin: const EdgeInsets.only(top: 10, left: 6),
      padding: const EdgeInsets.only(left: 12),
      decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.border, width: 2))),
      child: Column(
        children: [
          for (final sub in t.subtasks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => s.updateSubtask(t.id, sub.id, completed: !sub.completed),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: sub.completed ? AppColors.success : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: sub.completed ? AppColors.success : AppColors.textMuted, width: 1.5),
                      ),
                      child: sub.completed ? const Icon(LucideIcons.check, size: 12, color: Colors.white) : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sub.title,
                      style: TextStyle(
                        fontSize: 13,
                        decoration: sub.completed ? TextDecoration.lineThrough : null,
                        color: sub.completed ? AppColors.textMuted : AppColors.text,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => s.deleteSubtask(t.id, sub.id),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(LucideIcons.x, size: 13, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _sub,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Add subtask...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    onSubmitted: (_) => add(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Btn(label: '+', kind: BtnKind.secondary, small: true, onPressed: add),
            ],
          ),
        ],
      ),
    );
  }
}
