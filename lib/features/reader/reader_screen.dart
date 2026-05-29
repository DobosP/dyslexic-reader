import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/reading_theme.dart';
import '../../domain/models/reading_document.dart';
import '../settings/reading_prefs_controller.dart';
import '../settings/settings_screen.dart';
import 'widgets/reflow_text.dart';

class ReaderScreen extends ConsumerWidget {
  const ReaderScreen({super.key, required this.document});

  final ReadingDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(readingPrefsProvider);
    final palette = paletteFor(prefs.themeId);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.onBackground,
        title: Text(document.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Quick text size',
            icon: const Icon(Icons.format_size),
            onPressed: () => _quickSize(context),
          ),
          IconButton(
            tooltip: 'Reading settings',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ReflowText(
          document: document,
          prefs: prefs,
          textColor: palette.onBackground,
        ),
      ),
    );
  }

  void _quickSize(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final size = ref.watch(
            readingPrefsProvider.select((p) => p.fontSizeSp),
          );
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Text size: ${size.round()}'),
                Slider(
                  value: size,
                  min: 12,
                  max: 40,
                  divisions: 28,
                  label: size.round().toString(),
                  onChanged: (v) =>
                      ref.read(readingPrefsProvider.notifier).setFontSize(v),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
