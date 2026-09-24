import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../logic.dart';
import '../theme.dart';
import '../widgets/focus_controls.dart';
import '../widgets/ui.dart';

class FocusScreen extends StatelessWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final f = s.data.focus;
    final isWork = f.mode == 'work';
    final logs = s.data.pomoLogs.where((l) => l.date == s.today).toList();
    final openTasks = tasksForDate(s.data.tasks, s.today).where((t) => !t.completed).toList();
    final attached = f.attachedTaskId == null ? null : s.data.tasks.where((t) => t.id == f.attachedTaskId).firstOrNull;
    final options = [if (attached != null && !openTasks.contains(attached)) attached, ...openTasks];

    return Column(
      children: [
        const AppHeader(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: s.refresh,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // .focus-timer-area
                Panel(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                  borderColor: Colors.transparent,
                  child: Column(
                    children: [
                      const ModeTabs(),
                      const SizedBox(height: 18),
                      const _TimerRing(size: 236),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (f.running)
                            Btn(
                              label: 'Pause',
                              icon: LucideIcons.pause,
                              kind: BtnKind.secondary,
                              round: true,
                              onPressed: () => s.focusAction('pause'),
                            )
                          else
                            Btn(
                              label: 'Start',
                              icon: LucideIcons.play,
                              round: true,
                              onPressed: () => s.focusAction('start'),
                            ),
                          Btn(
                            label: 'Reset',
                            icon: LucideIcons.rotateCcw,
                            kind: BtnKind.secondary,
                            round: true,
                            onPressed: () => s.focusAction('reset'),
                          ),
                          if (!isWork)
                            Btn(
                              label: 'Skip',
                              icon: LucideIcons.skipForward,
                              kind: BtnKind.secondary,
                              round: true,
                              onPressed: () => s.focusAction('skip'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const CycleProgress(),
                      const SizedBox(height: 10),
                      Text.rich(
                        TextSpan(
                          text: 'Sessions completed: ',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          children: [
                            TextSpan(
                              text: '${f.sessionCount}',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Btn(
                        label: 'Fullscreen Focus',
                        icon: LucideIcons.maximize2,
                        kind: BtnKind.secondary,
                        onPressed:
                            () => Navigator.of(context).push(
                              PageRouteBuilder(
                                opaque: true,
                                pageBuilder:
                                    (_, _, _) =>
                                        ChangeNotifierProvider.value(value: s, child: const FocusOverlayScreen()),
                                transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _FocusCard(
                  title: 'Attach task',
                  child: DropdownButtonFormField<String?>(
                    value: f.attachedTaskId,
                    isExpanded: true,
                    dropdownColor: AppColors.surface2,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      for (final t in options)
                        DropdownMenuItem(
                          value: t.id,
                          child: Text(
                            t.title +
                                (t.goalId == null
                                    ? ''
                                    : ' [${s.data.goals.where((g) => g.id == t.goalId).firstOrNull?.title ?? ''}]'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: s.attachTask,
                  ),
                ),
                const SizedBox(height: 16),
                const _MusicCard(),
                const SizedBox(height: 16),
                _FocusCard(
                  title: 'Timer settings',
                  child: Column(
                    children: [
                      _SettingRow(label: 'Work', field: 'pomoWork', value: s.data.user.settings.pomoWork, max: 120),
                      _SettingRow(
                        label: 'Short',
                        field: 'pomoShortBreak',
                        value: s.data.user.settings.pomoShortBreak,
                        max: 60,
                      ),
                      _SettingRow(
                        label: 'Long',
                        field: 'pomoLongBreak',
                        value: s.data.user.settings.pomoLongBreak,
                        max: 60,
                      ),
                      _SettingRow(
                        label: 'Interval',
                        field: 'pomoLongInterval',
                        value: s.data.user.settings.pomoLongInterval,
                        max: 10,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _FocusCard(
                  title: 'Today sessions',
                  child:
                      logs.isEmpty
                          ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'No sessions yet today.',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w800),
                              ),
                            ),
                          )
                          : Column(
                            children: [
                              for (final l in logs.reversed.take(10))
                                Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface2,
                                    borderRadius: BorderRadius.circular(AppRadius.xs),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          s.data.tasks.where((t) => t.id == l.taskId).firstOrNull?.title ?? 'Untracked',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ),
                                      Text(
                                        '${l.sessions}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
}

/// `.timer-ring`: progress circle with the countdown and mode label.
class _TimerRing extends StatelessWidget {
  const _TimerRing({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final f = s.data.focus;
    final isWork = f.mode == 'work';
    return ValueListenableBuilder<int>(
      valueListenable: s.secondsLeft,
      builder: (context, secs, _) {
        final progress = f.totalSeconds > 0 ? (f.totalSeconds - secs) / f.totalSeconds : 0.0;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: progress.clamp(0, 1).toDouble()),
                duration: const Duration(seconds: 1),
                builder:
                    (_, v, _) => CustomPaint(
                      size: Size.square(size),
                      painter: _RingPainter(v, isWork ? AppColors.primary : AppColors.success),
                    ),
              ),
              Text(
                fmtClock(secs),
                style: TextStyle(
                  fontSize: size * 0.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Positioned(
                bottom: size * 0.28,
                child: Text(
                  focusModeLabel(f.mode),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.65,
                    color: isWork ? AppColors.primary : AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color);
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final r = size.width / 2 - stroke;
    final c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.surface3,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}

/// `.focus-card`.
class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.all(12),
    borderColor: Colors.transparent,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Kicker(title), const SizedBox(height: 8), child],
    ),
  );
}

class _MusicCard extends StatefulWidget {
  const _MusicCard();
  @override
  State<_MusicCard> createState() => _MusicCardState();
}

class _MusicCardState extends State<_MusicCard> {
  late final TextEditingController _url;
  String _synced = '';

  @override
  void initState() {
    super.initState();
    _synced = context.read<AppState>().data.user.settings.youtubeUrl;
    _url = TextEditingController(text: _synced);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<bool> _save({bool silent = false}) async {
    final s = context.read<AppState>();
    final url = _url.text.trim();
    if (url.isNotEmpty && youtubeId(url).isEmpty) {
      s.toast('Paste a valid YouTube link', ToastType.error);
      return false;
    }
    if (url != s.data.user.settings.youtubeUrl && !await s.updateSettings({'youtubeUrl': url})) return false;
    if (!silent) s.toast('Music saved', ToastType.success);
    return true;
  }

  Future<void> _play() async {
    if (!await _save(silent: true)) return;
    final id = youtubeId(_url.text);
    if (id.isEmpty) return;
    // Opens the YouTube app (keeps playing in the background with Premium / PiP).
    await launchUrl(Uri.parse('https://www.youtube.com/watch?v=$id'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final saved = s.data.user.settings.youtubeUrl;
    if (saved != _synced) {
      _synced = saved; // changed on the website
      _url.text = saved;
    }
    return _FocusCard(
      title: 'Background music',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(hintText: 'Paste YouTube link'),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: 8),
              Btn(label: 'Save', small: true, onPressed: _save),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Btn(label: 'Play', icon: LucideIcons.music, kind: BtnKind.secondary, small: true, onPressed: _play),
              const Spacer(),
              const Text(
                'Alarm',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w800),
              ),
              Switch(
                value: s.data.user.settings.alarmEnabled,
                activeTrackColor: AppColors.primary,
                onChanged: (v) => s.updateSettings({'alarmEnabled': v}),
              ),
            ],
          ),
          if (saved.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Save a YouTube link to use background music.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatefulWidget {
  const _SettingRow({required this.label, required this.field, required this.value, required this.max});
  final String label;
  final String field;
  final int value;
  final int max;
  @override
  State<_SettingRow> createState() => _SettingRowState();
}

class _SettingRowState extends State<_SettingRow> {
  late final TextEditingController _c = TextEditingController(text: '${widget.value}');
  Timer? _debounce;

  @override
  void didUpdateWidget(_SettingRow old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && int.tryParse(_c.text) != widget.value) _c.text = '${widget.value}';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _commit() {
    final v = int.tryParse(_c.text);
    if (v == null || v < 1 || v > widget.max || v == widget.value) return;
    context.read<AppState>().updateSettings({widget.field: v});
  }

  void _step(int d) {
    final v = ((int.tryParse(_c.text) ?? widget.value) + d).clamp(1, widget.max);
    _c.text = '$v';
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _commit);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(widget.label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: TextField(
            controller: _c,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 13),
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 800), _commit);
            },
            onSubmitted: (_) => _commit(),
          ),
        ),
        IconBtn(LucideIcons.minus, size: 16, onPressed: () => _step(-1)),
        IconBtn(LucideIcons.plus, size: 16, onPressed: () => _step(1)),
      ],
    ),
  );
}

/// `.focus-overlay`: distraction-free full screen timer.
class FocusOverlayScreen extends StatefulWidget {
  const FocusOverlayScreen({super.key});
  @override
  State<FocusOverlayScreen> createState() => _FocusOverlayScreenState();
}

class _FocusOverlayScreenState extends State<FocusOverlayScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final f = s.data.focus;
    final task = f.attachedTaskId == null ? null : s.data.tasks.where((t) => t.id == f.attachedTaskId).firstOrNull;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 12,
              right: 12,
              child: Btn(
                label: 'Exit Focus Mode',
                kind: BtnKind.secondary,
                round: true,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      task?.title ?? 'Deep Work Focus Session',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ValueListenableBuilder<int>(
                    valueListenable: s.secondsLeft,
                    builder:
                        (_, secs, _) => FittedBox(
                          child: Text(
                            fmtClock(secs),
                            style: const TextStyle(
                              fontSize: 110,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -4,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    focusModeLabel(f.mode),
                    style: const TextStyle(fontSize: 14, letterSpacing: 1.4, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 32),
                  Btn(
                    label: f.running ? 'Pause' : 'Start',
                    icon: f.running ? LucideIcons.pause : LucideIcons.play,
                    kind: f.running ? BtnKind.secondary : BtnKind.primary,
                    round: true,
                    onPressed: () => s.focusAction(f.running ? 'pause' : 'start'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
