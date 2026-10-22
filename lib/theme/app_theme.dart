import 'package:flutter/material.dart';

const _accent = Color(0xFF5B8CFF);
const _accent2 = Color(0xFF8A5BFF);

const accentGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_accent, _accent2],
);

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: _accent,
    brightness: brightness,
  ).copyWith(
    primary: dark ? const Color(0xFF8FB3FF) : const Color(0xFF3D6BE0),
    surface: dark ? const Color(0xFF0E1016) : const Color(0xFFF6F7FB),
    surfaceContainerLowest: dark ? const Color(0xFF0B0C11) : Colors.white,
    surfaceContainerLow: dark ? const Color(0xFF12141B) : const Color(0xFFFFFFFF),
    surfaceContainer: dark ? const Color(0xFF171A23) : const Color(0xFFEDEFF5),
    surfaceContainerHigh: dark ? const Color(0xFF1C2030) : const Color(0xFFE4E7EF),
    secondaryContainer: dark ? const Color(0xFF2B3350) : const Color(0xFFDCE5FF),
    onSecondaryContainer: dark ? const Color(0xFF8FB3FF) : const Color(0xFF1E3A8A),
    outlineVariant: dark ? const Color(0xFF1F2330) : const Color(0xFFDDE1EA),
  );

  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness);
  final text = base.textTheme;

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: scheme.onSurface,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.secondaryContainer,
      surfaceTintColor: Colors.transparent,
      height: 70,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainer,
      selectedColor: scheme.onSurface,
      labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
      secondaryLabelStyle: TextStyle(color: scheme.surface, fontSize: 13, fontWeight: FontWeight.w600),
      checkmarkColor: scheme.surface,
      showCheckmark: false,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
  );
}
