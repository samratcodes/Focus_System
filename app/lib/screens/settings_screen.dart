import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../platform.dart';
import '../logic.dart';
import '../services/notifications.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name;
  final _current = TextEditingController();
  final _new = TextEditingController();
  bool _savingPw = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: context.read<AppState>().data.user.name);
  }

  @override
  void dispose() {
    _name.dispose();
    _current.dispose();
    _new.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.data.user;
    final lvl = levelInfo(u.xp);

    return Column(
      children: [
        const AppHeader(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              // Profile / progress (the web sidebar's "Progress" card)
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primaryBg,
                          child: Text(
                            _initials(u.name),
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              Text(u.email, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0x26F59E0B), Color(0x266366F1)]),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: const Color(0x4DF59E0B)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.trophy, size: 14, color: AppColors.xpGold),
                          const SizedBox(width: 4),
                          Text(
                            'Lvl ${lvl.level} (${lvl.xpInLevel}/100 XP)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.xpGold),
                          ),
                          const Spacer(),
                          const Icon(LucideIcons.flame, size: 14, color: AppColors.frog),
                          const SizedBox(width: 4),
                          Text(
                            '${streakCount(s.data.streakDays, s.today)} day streak',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Profile',
                children: [
                  const FieldLabel('Name'),
                  TextField(controller: _name, maxLength: 80, decoration: const InputDecoration(counterText: '')),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Btn(
                      label: 'Save profile',
                      onPressed: () async {
                        final err = await s.updateProfile(name: _name.text.trim());
                        s.toast(err ?? 'Profile saved', err == null ? ToastType.success : ToastType.error);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Reminders & alarms',
                children: [
                  _ToggleRow(
                    label: 'Focus alarm sound',
                    value: u.settings.alarmEnabled,
                    onChanged: (v) => s.updateSettings({'alarmEnabled': v}),
                  ),
                  const SizedBox(height: 8),
                  const FieldLabel('Task reminders'),
                  DropdownButtonFormField<int>(
                    value:
                        const [-1, 0, 5, 10, 15, 30, 60].contains(u.settings.reminderMinutes)
                            ? u.settings.reminderMinutes
                            : 10,
                    dropdownColor: AppColors.surface2,
                    items: const [
                      DropdownMenuItem(value: -1, child: Text('Off')),
                      DropdownMenuItem(value: 0, child: Text('At start time')),
                      DropdownMenuItem(value: 5, child: Text('5 minutes before')),
                      DropdownMenuItem(value: 10, child: Text('10 minutes before')),
                      DropdownMenuItem(value: 15, child: Text('15 minutes before')),
                      DropdownMenuItem(value: 30, child: Text('30 minutes before')),
                      DropdownMenuItem(value: 60, child: Text('1 hour before')),
                    ],
                    onChanged: (v) => v == null ? null : s.updateSettings({'reminderMinutes': v}),
                  ),
                  const SizedBox(height: 6),
                  const Text('Tasks with a start time notify you on this phone.', style: AppText.muted),
                  const SizedBox(height: 10),
                  Btn(
                    label: 'Allow notifications & alarms',
                    icon: LucideIcons.bell,
                    kind: BtnKind.secondary,
                    onPressed: Notifications.requestPermissions,
                  ),
                ],
              ),
              if (supportsDeviceFeatures) const SizedBox(height: 14),
              if (supportsDeviceFeatures)
                _Section(
                  title: 'Home screen widget',
                  children: [
                    const Text(
                      "Add the Focus System widget to see today's tasks, tick them off and follow the focus timer "
                      'from your home screen — like Google Tasks.',
                      style: AppText.muted,
                    ),
                    const SizedBox(height: 10),
                    Btn(
                      label: 'Add widget to home screen',
                      icon: LucideIcons.layoutGrid,
                      kind: BtnKind.secondary,
                      onPressed: () async {
                        if (await HomeWidget.isRequestPinWidgetSupported() ?? false) {
                          await HomeWidget.requestPinWidget(
                            qualifiedAndroidName: 'com.focussystem.focus_system.TasksWidgetProvider',
                          );
                        } else {
                          s.toast('Long-press your home screen → Widgets → Focus System', ToastType.info);
                        }
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              _Section(
                title: 'Password',
                children: [
                  const FieldLabel('Current password'),
                  TextField(controller: _current, obscureText: true),
                  const SizedBox(height: 10),
                  const FieldLabel('New password'),
                  TextField(controller: _new, obscureText: true),
                  const SizedBox(height: 6),
                  const Text('At least 8 characters. Other devices will be signed out.', style: AppText.muted),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Btn(
                      label: 'Change password',
                      busy: _savingPw,
                      onPressed: () async {
                        if (_new.text.length < 8) {
                          return s.toast('New password must be at least 8 characters', ToastType.error);
                        }
                        setState(() => _savingPw = true);
                        final err = await s.updateProfile(currentPassword: _current.text, newPassword: _new.text);
                        if (!mounted) return;
                        setState(() => _savingPw = false);
                        if (err == null) {
                          _current.clear();
                          _new.clear();
                        }
                        s.toast(
                          err ?? 'Password changed. Other devices were signed out.',
                          err == null ? ToastType.success : ToastType.error,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Session',
                children: [
                  Text('Connected to ${s.api.baseUrl}', style: AppText.muted),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Btn(label: 'Sign out', icon: LucideIcons.logOut, kind: BtnKind.secondary, onPressed: s.logout),
                      Btn(
                        label: 'Sign out everywhere',
                        kind: BtnKind.danger,
                        onPressed: () async {
                          final ok = await confirmDialog(
                            context,
                            title: 'Sign out everywhere?',
                            message: 'This signs you out on this phone, the website and every other device.',
                            confirmLabel: 'Sign out everywhere',
                            danger: true,
                          );
                          if (ok) await s.logout(everywhere: true);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 70),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Kicker(title), const SizedBox(height: 14), ...children],
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
      Switch(value: value, activeTrackColor: AppColors.primary, onChanged: onChanged),
    ],
  );
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
  final letters = parts.map((p) => p[0].toUpperCase()).join();
  return letters.isEmpty ? '?' : letters;
}
