import 'package:flutter/material.dart';

import '../../domain/models/reading_prefs.dart';

/// Background/foreground colours for a reading theme.
class ReadingPalette {
  const ReadingPalette({
    required this.background,
    required this.onBackground,
    required this.accent,
    required this.brightness,
  });

  final Color background;
  final Color onBackground;
  final Color accent;
  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;
}

ReadingPalette paletteFor(ReadingThemeId id) {
  switch (id) {
    case ReadingThemeId.cream:
      return const ReadingPalette(
        background: Color(0xFFFBF0D9),
        onBackground: Color(0xFF2B2B2B),
        accent: Color(0xFF7A5C2E),
        brightness: Brightness.light,
      );
    case ReadingThemeId.sepia:
      return const ReadingPalette(
        background: Color(0xFFF4ECD8),
        onBackground: Color(0xFF5B4636),
        accent: Color(0xFF8A6D3B),
        brightness: Brightness.light,
      );
    case ReadingThemeId.offWhite:
      return const ReadingPalette(
        background: Color(0xFFF7F7F2),
        onBackground: Color(0xFF1F1F1F),
        accent: Color(0xFF3A6EA5),
        brightness: Brightness.light,
      );
    case ReadingThemeId.dark:
      return const ReadingPalette(
        background: Color(0xFF1A1A1A),
        onBackground: Color(0xFFE8E8E8),
        accent: Color(0xFF9CC4E4),
        brightness: Brightness.dark,
      );
    case ReadingThemeId.highContrast:
      return const ReadingPalette(
        background: Color(0xFF000000),
        onBackground: Color(0xFFFFFFFF),
        accent: Color(0xFFFFD400),
        brightness: Brightness.dark,
      );
  }
}

/// App-wide [ThemeData] derived from the chosen reading theme so the chrome
/// matches the reading surface. The reading font is applied explicitly on the
/// reading surface, not globally, to keep UI controls in a familiar font.
ThemeData buildAppTheme(ReadingThemeId id) {
  final p = paletteFor(id);
  final scheme = ColorScheme.fromSeed(
    seedColor: p.accent,
    brightness: p.brightness,
  ).copyWith(surface: p.background, onSurface: p.onBackground);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.onBackground,
      elevation: 0,
    ),
  );
}
