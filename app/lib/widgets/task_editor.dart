import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../logic.dart';
import '../models.dart';
import '../theme.dart';
import 'ui.dart';

/// Opens the "New Task" / "Edit Task" sheet (port of the web modal).
Future<void> showTaskEditor(BuildContext context, {Task? task, String? date}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder:
      (_) => ChangeNotifierProvider.value(
        value: context.read<AppState>(),
        child: _TaskEditor(task: task, initialDate: date),
      ),
);

class _DraftSub {
  _DraftSub(this.id, String title, this.completed) : controller = TextEditingController(text: title);
  final String? id; // null = not saved yet
  final TextEditingController controller;
  final bool completed;
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({this.task, this.initialDate});
  final Task? task;
  final String? initialDate;
  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  final _newSub = TextEditingController();
  late String? _goalId;
  late String _dueDate;
  String? _start;
  String? _end;
  String? _eisenhower;
  late bool _priority;
  late bool _today;
  late List<_DraftSub> _subs;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? '');
    _desc = TextEditingController(text: t?.description ?? '');
    _goalId = t != null ? t.goalId : s.activeGoalId;
    final fallbackDate = widget.initialDate ?? (s.selectedDate.compareTo(s.today) < 0 ? s.today : s.selectedDate);
    _dueDate = t?.dueDate ?? fallbackDate;
    _start = t?.startTime;
    _end = t?.endTime;
    _eisenhower = t?.eisenhower;
    _priority = t?.isPriority ?? false;
    _today = t != null && t.dueDate == s.today;
    _subs = [for (final x in t?.subtasks ?? const <Subtask>[]) _DraftSub(x.id, x.title, x.completed)];
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _newSub.dispose();
    for (final x in _subs) {
      x.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final s = context.read<AppState>();
    final first = parseDate(s.today);
    final current = parseDate(_dueDate);
    final picked = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: DateTime(first.year + 5),
      initialDate: current.isBefore(first) ? first : current,
    );
    if (picked != null) setState(() => _dueDate = toDateStr(picked));
  }

  Future<String?> _pickTime(String? current) async {
    final m = timeToMinutes(current);
    final picked = await showTimePicker(
      context: context,
      initialTime: m == null ? TimeOfDay.now() : TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    return picked == null ? null : '${pad2(picked.hour)}:${pad2(picked.minute)}';
  }

  Future<void> _save() async {
    final s = context.read<AppState>();
    final t = widget.task;
    final title = _title.text.trim();
    if (title.isEmpty) return s.toast('Title is required', ToastType.error);
    final due = _today ? s.today : _dueDate;
    final scheduleChanged = t == null || due != t.dueDate || _start != t.startTime;
    if (scheduleChanged && due.compareTo(s.today) < 0) {
      return s.toast('Cannot schedule tasks in the past', ToastType.error);
    }
    if (scheduleChanged && _start != null && due == s.today && timeToMinutes(_start)! <= nowMinutes()) {
      return s.toast('Cannot set a start time in the past for today', ToastType.error);
    }

    setState(() => _saving = true);
    final fields = <String, Object?>{
      'title': title,
      'goalId': _goalId,
      'description': _desc.text,
      'dueDate': due,
      'startTime': _start,
      'endTime': _end,
      'eisenhower': _eisenhower,
      'isPriority': _priority,
    };

    if (t == null) {
      final created = await s.createTask({
        ...fields,
        'subtasks': [
          for (final x in _subs)
            if (x.controller.text.trim().isNotEmpty) {'title': x.controller.text.trim()},
        ],
      });
      if (!mounted) return;
      setState(() => _saving = false);
      if (created != null) Navigator.pop(context);
      return;
    }

    final updated = await s.updateTask(t.id, fields);
    if (updated == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    // Sync subtask edits.
    final keep = _subs.where((x) => x.id != null).map((x) => x.id).toSet();
    for (final orig in t.subtasks) {
      if (!keep.contains(orig.id)) await s.deleteSubtask(t.id, orig.id);
    }
    for (final x in _subs) {
      final text = x.controller.text.trim();
      if (x.id == null) {
        await s.addSubtask(t.id, text);
      } else {
        final orig = t.subtasks.where((o) => o.id == x.id).firstOrNull;
        if (orig != null && text.isNotEmpty && orig.title != text) await s.updateSubtask(t.id, x.id!, title: text);
      }
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final s = context.read<AppState>();
    if (await confirmDialog(context, title: 'Delete this task?', confirmLabel: 'Delete', danger: true)) {
      if (await s.deleteTask(widget.task!.id) && mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = widget.task;
    const eis = [
      ('do-first', 'Do First', AppColors.danger, AppColors.dangerBg),
      ('schedule', 'Schedule', AppColors.info, AppColors.infoBg),
      ('delegate', 'Delegate', AppColors.warning, AppColors.warningBg),
      ('eliminate', 'Eliminate', AppColors.textMuted, AppColors.surface3),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t == null ? 'New Task' : 'Edit Task',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            const FieldLabel('Title'),
            TextField(controller: _title, autofocus: t == null, textCapitalization: TextCapitalization.sentences),
            const SizedBox(height: 14),
            const FieldLabel('Associated Goal'),
            DropdownButtonFormField<String?>(
              value: s.data.goals.any((g) => g.id == _goalId) ? _goalId : null,
              dropdownColor: AppColors.surface2,
              items: [
                const DropdownMenuItem(value: null, child: Text('— Standalone Task —')),
                for (final g in s.data.goals) DropdownMenuItem(value: g.id, child: Text('🎯 ${g.title}')),
              ],
              onChanged: (v) => setState(() => _goalId = v),
            ),
            const SizedBox(height: 14),
            const FieldLabel('Description'),
            TextField(controller: _desc, minLines: 2, maxLines: 5),
            const SizedBox(height: 14),
            const FieldLabel('Due date & time'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PickerChip(
                  icon: LucideIcons.calendar,
                  label: _today ? 'Today' : fmtDate(_dueDate),
                  onTap: _today ? () => setState(() => _today = false) : _pickDate,
                ),
                PickerChip(
                  icon: LucideIcons.clock,
                  label: _start == null ? 'Start' : 'Start $_start',
                  onTap: () async {
                    final v = await _pickTime(_start);
                    if (v != null) setState(() => _start = v);
                  },
                  onClear: _start == null ? null : () => setState(() => _start = null),
                ),
                PickerChip(
                  icon: LucideIcons.clock,
                  label: _end == null ? 'End' : 'End $_end',
                  onTap: () async {
                    final v = await _pickTime(_end);
                    if (v != null) setState(() => _end = v);
                  },
                  onClear: _end == null ? null : () => setState(() => _end = null),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const FieldLabel('Eisenhower Priority'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (value, label, fg, bg) in eis)
                  GestureDetector(
                    onTap: () => setState(() => _eisenhower = _eisenhower == value ? null : value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _eisenhower == value ? bg : Colors.transparent,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: _eisenhower == value ? fg : AppColors.border, width: 1.5),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _eisenhower == value ? fg : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _check('Mark as priority task (+50 XP)', _priority, AppColors.frog, (v) => setState(() => _priority = v)),
            _check("Add to Today's list", _today, AppColors.primary, (v) => setState(() => _today = v)),
            const SizedBox(height: 8),
            const FieldLabel('Subtasks'),
            for (final x in _subs)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: x.controller,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                    IconBtn(LucideIcons.x, onPressed: () => setState(() => _subs.remove(x))),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newSub,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Add subtask...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onSubmitted: (_) => _addSub(),
                  ),
                ),
                const SizedBox(width: 6),
                Btn(label: '+', kind: BtnKind.secondary, small: true, onPressed: _addSub),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Btn(label: 'Cancel', kind: BtnKind.secondary, onPressed: () => Navigator.pop(context)),
                if (t != null) ...[
                  const SizedBox(width: 8),
                  Btn(label: 'Delete', kind: BtnKind.danger, onPressed: _delete),
                ],
                const SizedBox(width: 8),
                Btn(label: t == null ? 'Create Task' : 'Save Changes', busy: _saving, onPressed: _save),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addSub() {
    if (_newSub.text.trim().isEmpty) return;
    setState(() {
      _subs.add(_DraftSub(null, _newSub.text.trim(), false));
      _newSub.clear();
    });
  }

  Widget _check(String label, bool value, Color color, ValueChanged<bool> onChanged) => InkWell(
    onTap: () => onChanged(!value),
    child: Row(
      children: [
        Checkbox(value: value, activeColor: color, onChanged: (v) => onChanged(v ?? false)),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    ),
  );
}
