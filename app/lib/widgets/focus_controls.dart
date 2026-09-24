import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

/// Focus / Short break / Long break switcher (same as the website's mode tabs).
class ModeTabs extends StatelessWidget {
  const ModeTabs({super.key});

  static const _modes = [
    ('work', 'Focus', LucideIcons.brain),
    ('shortBreak', 'Short break', LucideIcons.coffee),
    ('longBreak', 'Long break', LucideIcons.sofa),
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final current = s.data.focus.mode;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final (mode, label, icon) in _modes)
            Expanded(
              child: _ModeTab(
                label: label,
                icon: icon,
                selected: current == mode,
                isBreak: mode != 'work',
                onTap: current == mode ? null : () => s.setFocusMode(mode),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.isBreak,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final bool isBreak;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = isBreak ? AppColors.success : AppColors.primaryHover;
    final color = selected ? accent : AppColors.textSecondary;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? (isBreak ? AppColors.successBg : AppColors.primaryBg) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dots for the sessions done before the long break, plus what comes next.
class CycleProgress extends StatelessWidget {
  const CycleProgress({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final f = s.data.focus;
    final st = s.data.user.settings;
    final interval = st.pomoLongInterval;
    final doneInCycle = f.sessionCount % interval;
    final isWork = f.mode == 'work';
    final nextIsLong = isWork && (f.sessionCount + 1) % interval == 0;
    final String next;
    if (!isWork) {
      next = 'Focus · ${st.pomoWork} min';
    } else if (nextIsLong) {
      next = 'Long break · ${st.pomoLongBreak} min';
    } else {
      next = 'Short break · ${st.pomoShortBreak} min';
    }
    return Semantics(
      label: '$doneInCycle of $interval sessions until a long break. Next: $next',
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < interval; i++)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < doneInCycle ? AppColors.primary : AppColors.surface3,
                    border: i == doneInCycle && isWork ? Border.all(color: AppColors.primary, width: 2) : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.coffee, size: 13, color: AppColors.success),
              const SizedBox(width: 6),
              Text(
                'Next: $next',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
