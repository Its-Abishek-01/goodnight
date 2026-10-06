import 'package:flutter/material.dart';

/// The night-sky palette: deep indigo with the golden moon from the logo.
class GnColors {
  static const skyTop = Color(0xFF1A1645);
  static const skyBottom = Color(0xFF0B0920);
  static const surface = Color(0xFF1E1A45);
  static const surfaceHigh = Color(0xFF2A2560);
  static const outline = Color(0xFF3A3570);
  static const moon = Color(0xFFFDE29B);
  static const onMoon = Color(0xFF3D2600);
  static const text = Color(0xFFF3F0FF);
  static const muted = Color(0xFFA9A3DD);
  static const lavender = Color(0xFFB9A6F4);
  static const danger = Color(0xFFFF8A9A);
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: GnColors.moon,
    onPrimary: GnColors.onMoon,
    secondary: GnColors.lavender,
    onSecondary: GnColors.skyBottom,
    surface: GnColors.surface,
    onSurface: GnColors.text,
    onSurfaceVariant: GnColors.muted,
    surfaceContainerHighest: GnColors.surfaceHigh,
    outline: GnColors.outline,
    outlineVariant: GnColors.outline,
    primaryContainer: Color(0xFF3B2F6E),
    onPrimaryContainer: GnColors.text,
    secondaryContainer: Color(0xFF332B66),
    onSecondaryContainer: GnColors.text,
    tertiary: Color(0xFFF4A6C6),
    tertiaryContainer: Color(0xFF4A2550),
    onTertiaryContainer: Color(0xFFFFE3EE),
    error: GnColors.danger,
    errorContainer: Color(0xFF5A2236),
    onErrorContainer: GnColors.text,
  );
  const pill = StadiumBorder();
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: Brightness.dark);
  final text = base.textTheme;
  return base.copyWith(
    // Buttons read labelLarge; a bolder, larger label suits the pill buttons.
    textTheme: text.copyWith(
      labelLarge: text.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    // The starry sky is painted behind every screen (see StarrySky).
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: GnColors.text,
    ),
    cardTheme: CardThemeData(
      color: GnColors.surface.withValues(alpha: 0.88),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: GnColors.outline.withValues(alpha: 0.6)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: GnColors.moon,
        foregroundColor: GnColors.onMoon,
        minimumSize: const Size(0, 48),
        shape: pill,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: GnColors.text,
        minimumSize: const Size(0, 48),
        shape: pill,
        side: const BorderSide(color: GnColors.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: GnColors.moon),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GnColors.surface.withValues(alpha: 0.9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: GnColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: GnColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: GnColors.moon, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: GnColors.skyBottom.withValues(alpha: 0.92),
      indicatorColor: GnColors.moon.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? GnColors.moon : GnColors.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          color: s.contains(WidgetState.selected) ? GnColors.moon : GnColors.muted,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: GnColors.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? GnColors.onMoon : GnColors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? GnColors.moon : GnColors.surfaceHigh,
      ),
    ),
    dividerTheme: const DividerThemeData(color: GnColors.outline),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: GnColors.surfaceHigh,
      contentTextStyle: TextStyle(color: GnColors.text),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
