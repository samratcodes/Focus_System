import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../platform.dart';
import '../theme.dart';
import '../widgets/task_editor.dart';
import 'analytics_screen.dart';
import 'calendar_screen.dart';
import 'focus_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';

/// Signed-in layout: the web sidebar becomes a bottom navigation bar.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  StreamSubscription<Uri?>? _widgetClicks;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    s.onOpenPayload = _openPayload;
    // Launched / resumed from the home-screen widget.
    if (supportsDeviceFeatures) {
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri);
      _widgetClicks = HomeWidget.widgetClicked.listen(_handleWidgetUri);
    }
  }

  @override
  void dispose() {
    _widgetClicks?.cancel();
    super.dispose();
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null || !mounted) return;
    final s = context.read<AppState>();
    switch (uri.host) {
      case 'add':
        s.setTab(0);
        _openPayload('add');
      case 'task':
        final id = uri.queryParameters['id'];
        s.setTab(0);
        if (id != null) _openPayload('task:$id');
      case 'focus':
        s.setTab(2);
      default:
        s.setTab(0);
    }
  }

  void _openPayload(String payload) {
    if (!mounted) return;
    final s = context.read<AppState>();
    if (!s.signedIn) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (payload == 'add') {
        showTaskEditor(context);
      } else if (payload.startsWith('task:')) {
        final task = s.data.tasks.where((t) => t.id == payload.substring(5)).firstOrNull;
        if (task != null) showTaskEditor(context, task: task);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final todayCount = s.data.tasks.where((t) => t.dueDate == s.today).length;

    const screens = [TodayScreen(), CalendarScreen(), FocusScreen(), AnalyticsScreen(), SettingsScreen()];
    return Scaffold(
      body: IndexedStack(index: s.tab, children: screens),
      floatingActionButton:
          s.tab <= 1
              ? FloatingActionButton(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                tooltip: 'New task',
                onPressed: () => showTaskEditor(context, date: s.tab == 1 ? s.selectedDate : null),
                child: const Icon(LucideIcons.plus),
              )
              : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                _NavItem(icon: LucideIcons.sun, label: 'Today', index: 0, badge: '$todayCount'),
                const _NavItem(icon: LucideIcons.calendar, label: 'Calendar', index: 1),
                _NavItem(icon: LucideIcons.timer, label: 'Focus', index: 2, badge: s.data.focus.running ? 'On' : null),
                const _NavItem(icon: LucideIcons.chartColumn, label: 'Analytics', index: 3),
                const _NavItem(icon: LucideIcons.settings, label: 'Settings', index: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.nav-item` (+ `.nav-badge`), active state = primary tint.
class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.index, this.badge});
  final IconData icon;
  final String label;
  final int index;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final active = s.tab == index;
    final color = active ? AppColors.primary : AppColors.textSecondary;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () => s.setTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryBg : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: badge != null && badge != '0',
                label: Text(badge ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                backgroundColor: AppColors.primary,
                textColor: Colors.white,
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: color, fontWeight: active ? FontWeight.w600 : FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
