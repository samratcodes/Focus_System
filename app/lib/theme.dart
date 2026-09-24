import 'package:flutter/material.dart';

/// Colour tokens copied from the website's CSS variables (styles.css :root).
class AppColors {
  static const bg = Color(0xFF09090B);
  static const surface = Color(0xFF121215);
  static const surface2 = Color(0xFF1A1A1F);
  static const surface3 = Color(0xFF25252B);
  static const text = Color(0xFFFAFAFA);
  static const textSecondary = Color(0xFFA1A1AA);
  static const textMuted = Color(0xFF52525B);
  static const border = Color(0xFF25252B);
  static const borderLight = Color(0xFF1A1A1F);
  static const primary = Color(0xFF6366F1);
  static const primaryHover = Color(0xFF818CF8);
  static const primaryBg = Color(0x266366F1); // rgba(99,102,241,0.15)
  static const success = Color(0xFF10B981);
  static const successBg = Color(0x2610B981);
  static const warning = Color(0xFFF59E0B);
  static const warningBg = Color(0x26F59E0B);
  static const danger = Color(0xFFEF4444);
  static const dangerBg = Color(0x26EF4444);
  static const info = Color(0xFF3B82F6);
  static const infoBg = Color(0x263B82F6);
  static const frog = Color(0xFFF97316);
  static const frogBg = Color(0x26F97316);
  static const xpGold = Color(0xFFF59E0B);

  static Color parse(String hex, [Color fallback = primary]) {
    final h = hex.replaceFirst('#', '');
    if (h.length != 6) return fallback;
    final v = int.tryParse(h, radix: 16);
    return v == null ? fallback : Color(0xFF000000 | v);
  }
}

class AppRadius {
  static const panel = 12.0; // .daily-board, .workflow-panel … (v2: rounder)
  static const card = 12.0; // task cards
  static const sm = 6.0; // --radius-sm (buttons, inputs)
  static const xs = 4.0;
}

/// Small text styles reused across screens (mirroring the CSS classes).
class AppText {
  static const kicker = TextStyle(
    fontSize: 11,
    color: AppColors.textMuted,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.55,
  );
  static const label = TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w800);
  static const h1 = TextStyle(fontSize: 24, height: 1.2, fontWeight: FontWeight.w900, color: AppColors.text);
  static const h2 = TextStyle(fontSize: 16, height: 1.25, fontWeight: FontWeight.w800, color: AppColors.text);
  static const body = TextStyle(fontSize: 14, color: AppColors.text);
  static const muted = TextStyle(fontSize: 13, color: AppColors.textSecondary);
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.success,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    error: AppColors.danger,
  );
  OutlineInputBorder border(Color c) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: c));
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.surface,
    dividerColor: AppColors.border,
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface2,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primary),
      errorBorder: border(AppColors.danger),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
    ),
    checkboxTheme: CheckboxThemeData(
      side: const BorderSide(color: AppColors.textMuted, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      dragHandleColor: AppColors.surface3,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: AppColors.primary),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
  );
}

class AppGradients {
  /// Brand gradient (indigo → violet), same as the website's --grad-primary.
  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
  );
  static const success = LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)]);
}
