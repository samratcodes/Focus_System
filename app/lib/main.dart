import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'platform.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/notifications.dart';
import 'services/widget_sync.dart';
import 'theme.dart';
import 'widgets/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
    ),
  );
  if (supportsDeviceFeatures) {
    await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
    await Notifications.init();
  }
  runApp(ChangeNotifierProvider(create: (_) => AppState()..start(), child: const FocusSystemApp()));
}

class FocusSystemApp extends StatefulWidget {
  const FocusSystemApp({super.key});
  @override
  State<FocusSystemApp> createState() => _FocusSystemAppState();
}

class _FocusSystemAppState extends State<FocusSystemApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    context.read<AppState>().onToast = (msg, type) {
      final m = _messenger.currentState;
      if (m != null) showToast(m, msg, type);
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return MaterialApp(
      title: 'Focus System',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      scaffoldMessengerKey: _messenger,
      home:
          s.booting
              ? const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.target, size: 40, color: AppColors.primary),
                      SizedBox(height: 16),
                      SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                ),
              )
              : (s.signedIn ? const HomeShell() : const LoginScreen()),
    );
  }
}
