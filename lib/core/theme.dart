import 'package:flutter/material.dart';

/// The time of day the app is dressed for.
enum SkyPhase {
  dawn,
  day,
  dusk,
  night;

  /// Dawn and day use the light palette; dusk and night the dark one.
  bool get isLight => this == dawn || this == day;
}

/// Night 21:00-05:00, dawn 05:00-08:00, day 08:00-17:00, dusk 17:00-21:00.
SkyPhase skyPhaseAt(DateTime t) {
  final h = t.hour;
  if (h >= 21 || h < 5) return SkyPhase.night;
  if (h < 8) return SkyPhase.dawn;
  if (h < 17) return SkyPhase.day;
  return SkyPhase.dusk;
}

/// Colours for one time of day. Reach them with `context.sky`.
@immutable
class SkyColors extends ThemeExtension<SkyColors> {
  const SkyColors({
    required this.sky,
    required this.surface,
    required this.surfaceHigh,
    required this.outline,
    required this.accent,
    required this.onAccent,
    required this.text,
    required this.muted,
    required this.navBar,
  });

  /// Background gradient, top to bottom.
  final List<Color> sky;
  final Color surface;
  final Color surfaceHigh;
  final Color outline;

  /// The moon's gold at night, the sun's orange by day.
  final Color accent;
  final Color onAccent;
  final Color text;
  final Color muted;
  final Color navBar;

  static const night = SkyColors(
    sky: [Color(0xFF1A1645), Color(0xFF120F35), Color(0xFF0B0920)],
    surface: Color(0xFF1E1A45),
    surfaceHigh: Color(0xFF2A2560),
    outline: Color(0xFF3A3570),
    accent: Color(0xFFFDE29B),
    onAccent: Color(0xFF3D2600),
    text: Color(0xFFF3F0FF),
    muted: Color(0xFFA9A3DD),
    navBar: Color(0xFF0B0920),
  );

  static const dusk = SkyColors(
    sky: [Color(0xFF2B1F5C), Color(0xFF6B3A78), Color(0xFFD9806A)],
    surface: Color(0xFF2A1F55),
    surfaceHigh: Color(0xFF3A2C6E),
    outline: Color(0xFF574683),
    accent: Color(0xFFFDE29B),
    onAccent: Color(0xFF3D2600),
    text: Color(0xFFFFF4F0),
    muted: Color(0xFFD7C3E6),
    navBar: Color(0xFF231A4A),
  );

  static const dawn = SkyColors(
    sky: [Color(0xFFB9C8F2), Color(0xFFFBC9C9), Color(0xFFFFE3B8)],
    surface: Color(0xFFFFFBF7),
    surfaceHigh: Color(0xFFFFF1E6),
    outline: Color(0xFFEBD3D6),
    accent: Color(0xFFFFAE52),
    onAccent: Color(0xFF4A2500),
    text: Color(0xFF2B1B3A),
    muted: Color(0xFF7A6A8C),
    navBar: Color(0xFFFFF8F2),
  );

  static const day = SkyColors(
    sky: [Color(0xFF6FB7F0), Color(0xFFA9D8F7), Color(0xFFE8F5FF)],
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF1F7FF),
    outline: Color(0xFFD3E2F2),
    accent: Color(0xFFFFAE52),
    onAccent: Color(0xFF4A2500),
    text: Color(0xFF1F2A44),
    muted: Color(0xFF5F6B85),
    navBar: Color(0xFFFFFFFF),
  );

  static SkyColors of(SkyPhase p) => switch (p) {
        SkyPhase.night => night,
        SkyPhase.dusk => dusk,
        SkyPhase.dawn => dawn,
        SkyPhase.day => day,
      };

  @override
  SkyColors copyWith() => this;

  @override
  SkyColors lerp(SkyColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return SkyColors(
      sky: [for (var i = 0; i < 3; i++) c(sky[i], other.sky[i])],
      surface: c(surface, other.surface),
      surfaceHigh: c(surfaceHigh, other.surfaceHigh),
      outline: c(outline, other.outline),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      text: c(text, other.text),
      muted: c(muted, other.muted),
      navBar: c(navBar, other.navBar),
    );
  }
}

extension SkyContext on BuildContext {
  SkyColors get sky => Theme.of(this).extension<SkyColors>() ?? SkyColors.night;
}

const _danger = Color(0xFFE5486A);

ThemeData buildTheme([SkyPhase phase = SkyPhase.night]) {
  final s = SkyColors.of(phase);
  final light = phase.isLight;
  final scheme = ColorScheme(
    brightness: light ? Brightness.light : Brightness.dark,
    primary: s.accent,
    onPrimary: s.onAccent,
    secondary: light ? const Color(0xFF7C6CD6) : const Color(0xFFB9A6F4),
    onSecondary: light ? Colors.white : const Color(0xFF0B0920),
    surface: s.surface,
    onSurface: s.text,
    onSurfaceVariant: s.muted,
    surfaceContainerHighest: s.surfaceHigh,
    outline: s.outline,
    outlineVariant: s.outline,
    primaryContainer: light ? const Color(0xFFFFE6C7) : const Color(0xFF3B2F6E),
    onPrimaryContainer: s.text,
    secondaryContainer: light ? const Color(0xFFE9E3FF) : const Color(0xFF332B66),
    onSecondaryContainer: s.text,
    tertiary: const Color(0xFFF4A6C6),
    onTertiary: const Color(0xFF5A1534),
    tertiaryContainer: light ? const Color(0xFFFFE0EC) : const Color(0xFF4A2550),
    onTertiaryContainer: light ? const Color(0xFF5A1534) : const Color(0xFFFFE3EE),
    error: light ? _danger : const Color(0xFFFF8A9A),
    onError: Colors.white,
    errorContainer: light ? const Color(0xFFFFDCE3) : const Color(0xFF5A2236),
    onErrorContainer: s.text,
  );
  const pill = StadiumBorder();
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final text = base.textTheme;
  return base.copyWith(
    extensions: [s],
    // Buttons read labelLarge; a bolder, larger label suits the pill buttons.
    textTheme: text.copyWith(
      labelLarge: text.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    // The living sky is painted behind every screen (see LivingSky).
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: s.text,
    ),
    cardTheme: CardThemeData(
      color: s.surface.withValues(alpha: light ? 0.82 : 0.88),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: s.outline.withValues(alpha: 0.6)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: s.accent,
        foregroundColor: s.onAccent,
        minimumSize: const Size(0, 48),
        shape: pill,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: s.text,
        minimumSize: const Size(0, 48),
        shape: pill,
        side: BorderSide(color: s.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: light ? const Color(0xFFD9741C) : s.accent),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: s.surface.withValues(alpha: 0.9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: s.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: s.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: s.accent, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: s.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: s.surfaceHigh),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected) ? s.onAccent : s.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected) ? s.accent : s.surfaceHigh,
      ),
    ),
    dividerTheme: DividerThemeData(color: s.outline),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: s.surfaceHigh,
      contentTextStyle: TextStyle(color: s.text),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
