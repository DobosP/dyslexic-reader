import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/reading_prefs.dart';
import '../reading_prefs_controller.dart';

/// Reusable reading-preference controls shared by the full Settings screen and
/// the reader's quick "Text & display" sheet, so the two never drift out of
/// sync. Each control watches [readingPrefsProvider] itself and reads the
/// notifier to apply changes, so callers just drop them in.

/// Theme-selection chips (cream / sepia / dark / …).
class ThemeChoiceChips extends ConsumerWidget {
  const ThemeChoiceChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(readingPrefsProvider.select((p) => p.themeId));
    final controller = ref.read(readingPrefsProvider.notifier);
    return Wrap(
      spacing: 8,
      children: [
        for (final t in ReadingThemeId.values)
          ChoiceChip(
            label: Text(t.label),
            selected: selected == t,
            onSelected: (_) => controller.setTheme(t),
          ),
      ],
    );
  }
}

/// Font-family chips (OpenDyslexic / Atkinson Hyperlegible / Lexend / …).
class FontChoiceChips extends ConsumerWidget {
  const FontChoiceChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(readingPrefsProvider.select((p) => p.fontFamily));
    final controller = ref.read(readingPrefsProvider.notifier);
    return Wrap(
      spacing: 8,
      children: [
        for (final f in ReadingFontFamily.values)
          ChoiceChip(
            label: Text(f.label),
            selected: selected == f,
            onSelected: (_) => controller.setFont(f),
          ),
      ],
    );
  }
}
