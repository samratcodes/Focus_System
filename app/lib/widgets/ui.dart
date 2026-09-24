import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../logic.dart';
import '../theme.dart';

/// `.daily-board` / `.workflow-panel` / `.analytics-card`: bordered surface block.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.borderColor});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.panel),
      border: Border.all(color: borderColor ?? AppColors.border),
    ),
    child: child,
  );
}

/// `.panel-kicker` — small uppercase label.
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: AppText.kicker.copyWith(color: color ?? AppColors.textMuted));
}

/// `.section-title` — kicker on the left, bold title on the right.
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.kicker, required this.title});
  final String kicker;
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [Kicker(kicker), const Spacer(), Text(title, style: AppText.h2)],
  );
}

/// `.badge` pill.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.fg, required this.bg, this.border});
  final String label;
  final Color fg;
  final Color bg;
  final Color? border;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(99),
      border: border == null ? null : Border.all(color: border!),
    ),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: fg),
    ),
  );
}

enum BtnKind { primary, secondary, danger, ghost }

/// `.btn` / `.btn-primary` / `.btn-secondary` / `.btn-danger` / `.btn-sm`.
class Btn extends StatelessWidget {
  const Btn({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.kind = BtnKind.primary,
    this.small = false,
    this.round = false,
    this.expand = false,
    this.busy = false,
    this.semanticLabel,
  });
  final String label;
  final String? semanticLabel; // for icon-only buttons
  final IconData? icon;
  final VoidCallback? onPressed;
  final BtnKind kind;
  final bool small;
  final bool round;
  final bool expand;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      BtnKind.primary => (AppColors.primary, Colors.white),
      BtnKind.secondary => (AppColors.surface2, AppColors.text),
      BtnKind.danger => (AppColors.dangerBg, AppColors.danger),
      BtnKind.ghost => (Colors.transparent, AppColors.textSecondary),
    };
    final disabled = onPressed == null || busy;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        else if (icon != null)
          Icon(icon, size: small ? 14 : (round ? 20 : 17), color: fg),
        if ((icon != null || busy) && label.isNotEmpty) SizedBox(width: small ? 5 : 7),
        if (label.isNotEmpty)
          Text(
            label,
            style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: small ? 12 : (round ? 15 : 13)),
          ),
      ],
    );
    return Semantics(
      container: true,
      button: true,
      enabled: !disabled,
      label: label.isEmpty ? semanticLabel : label,
      excludeSemantics: true,
      child: Opacity(
        opacity: disabled && !busy ? 0.6 : 1,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(round ? 99 : (small ? AppRadius.xs : AppRadius.sm)),
          child: InkWell(
            borderRadius: BorderRadius.circular(round ? 99 : (small ? AppRadius.xs : AppRadius.sm)),
            onTap: disabled ? null : onPressed,
            child: Padding(
              padding:
                  round
                      ? const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                      : small
                      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
                      : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// `.btn-icon`.
class IconBtn extends StatelessWidget {
  const IconBtn(this.icon, {super.key, this.onPressed, this.color, this.size = 18, this.tooltip});
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final String? tooltip;
  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: tooltip,
    icon: Icon(icon, size: size, color: color ?? AppColors.textSecondary),
    visualDensity: VisualDensity.compact,
    style: IconButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm))),
  );
}

/// `.daily-progress` / `.stat-bar` / `.mini-track`.
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({super.key, required this.value, this.color = AppColors.success, this.height = 8});
  final double value; // 0..1
  final Color color;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height / 2),
    child: Container(
      height: height,
      color: AppColors.surface3,
      alignment: Alignment.centerLeft,
      child: AnimatedFractionallySizedBox(
        duration: const Duration(milliseconds: 350),
        widthFactor: value.clamp(0, 1).toDouble(),
        child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height / 2))),
      ),
    ),
  );
}

/// `.daily-score` — "3/5 DONE" box.
class DailyScore extends StatelessWidget {
  const DailyScore({super.key, required this.done, required this.total, this.small = false});
  final int done;
  final int total;
  final bool small;
  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minWidth: small ? 72 : 88),
    padding: EdgeInsets.symmetric(horizontal: small ? 10 : 12, vertical: small ? 8 : 10),
    decoration: BoxDecoration(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(AppRadius.panel),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        Text(
          '$done/$total',
          style: TextStyle(
            fontSize: small ? 18 : 22,
            height: 1,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'DONE',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
      ],
    ),
  );
}

/// `.empty-state`.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.compact = false});
  final IconData icon;
  final String title;
  final String message;
  final bool compact;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: compact ? 24 : 40, horizontal: 20),
    child: Column(
      children: [
        Icon(icon, size: 32, color: AppColors.textMuted.withValues(alpha: 0.6)),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
      ],
    ),
  );
}

/// The top `.header`: greeting, date/time and today's completion bar.
class AppHeader extends StatefulWidget {
  const AppHeader({super.key, this.trailing});
  final Widget? trailing;
  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  late Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 20), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final rate = completionRate(s.data.tasks, s.today);
    final first = s.data.user.name.split(RegExp(r'\s+')).first;
    final date = MaterialLocalizations.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${greeting(_now)}, $first',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${date.formatFullDate(_now)} · ${date.formatTimeOfDay(TimeOfDay.fromDateTime(_now))}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (!s.online)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Tooltip(
                    message: 'Offline — changes may not be saved',
                    child: Icon(LucideIcons.cloudOff, size: 18, color: AppColors.warning),
                  ),
                ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: ProgressTrack(value: rate / 100, height: 6)),
              const SizedBox(width: 10),
              Text(
                '$rate%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ toasts

/// Web-style toast (`.toast.success` etc.) at the bottom of the screen.
void showToast(ScaffoldMessengerState messenger, String msg, ToastType type) {
  final color = switch (type) {
    ToastType.success => AppColors.success,
    ToastType.error => AppColors.danger,
    ToastType.info => AppColors.info,
    ToastType.normal => AppColors.text,
  };
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      duration: const Duration(milliseconds: 2500),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: type == ToastType.normal ? AppColors.border : color),
          boxShadow: [
            BoxShadow(
              color: type == ToastType.success ? AppColors.success.withValues(alpha: 0.2) : Colors.black54,
              blurRadius: 20,
            ),
          ],
        ),
        child: Text(msg, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    ),
  );
}

// ------------------------------------------------------------------ dialogs

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          content: message == null ? null : Text(message, style: AppText.muted.copyWith(fontSize: 14)),
          actions: [
            Btn(label: 'Cancel', kind: BtnKind.secondary, onPressed: () => Navigator.pop(ctx, false)),
            Btn(
              label: confirmLabel,
              kind: danger ? BtnKind.danger : BtnKind.primary,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
  );
  return ok ?? false;
}

/// Create / edit goal: name + colour swatches.
Future<({String name, String color})?> goalDialog(
  BuildContext context, {
  required String title,
  String initialName = '',
  String? initialColor,
  String submitLabel = 'Save',
}) {
  final controller = TextEditingController(text: initialName);
  var color = initialColor ?? (goalColors.toList()..shuffle()).first;
  const swatches = [
    '#4F46E5',
    '#059669',
    '#D97706',
    '#DC2626',
    '#DB2777',
    '#7C3AED',
    '#6366F1',
    '#10B981',
    '#0EA5E9',
    '#F97316',
  ];
  return showDialog<({String name, String color})>(
    context: context,
    builder:
        (ctx) => StatefulBuilder(
          builder: (ctx, setState) {
            void submit() {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx, (name: controller.text.trim(), color: color));
            }

            return AlertDialog(
              title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Goal name'),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 80,
                    decoration: const InputDecoration(counterText: ''),
                    onSubmitted: (_) => submit(),
                  ),
                  const SizedBox(height: 14),
                  const FieldLabel('Color'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in swatches)
                        GestureDetector(
                          onTap: () => setState(() => color = c),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.parse(c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: c.toLowerCase() == color.toLowerCase() ? AppColors.text : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              actions: [
                Btn(label: 'Cancel', kind: BtnKind.secondary, onPressed: () => Navigator.pop(ctx)),
                Btn(label: submitLabel, onPressed: submit),
              ],
            );
          },
        ),
  );
}

/// `.form-group label`.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.45,
      ),
    ),
  );
}

/// Compact tappable field used for date/time pickers (like `.quick-options` inputs).
class PickerChip extends StatelessWidget {
  const PickerChip({super.key, required this.icon, required this.label, required this.onTap, this.onClear});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      side: const BorderSide(color: AppColors.border),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13)),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(onTap: onClear, child: const Icon(LucideIcons.x, size: 14, color: AppColors.textMuted)),
            ],
          ],
        ),
      ),
    ),
  );
}
