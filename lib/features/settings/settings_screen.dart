import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/reading_theme.dart';
import '../../domain/reflow/tokenizer.dart';
import '../../domain/models/reading_prefs.dart';
import '../reader/widgets/reflow_text.dart';
import 'reading_prefs_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(readingPrefsProvider);
    final c = ref.read(readingPrefsProvider.notifier);
    final palette = paletteFor(prefs.themeId);

    final preview = Tokenizer.parse(
      'The quick brown fox jumps over the lazy dog. '
      'Comfortable spacing makes reading calmer.',
      title: 'Preview',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading settings'),
        actions: [
          TextButton(onPressed: c.reset, child: const Text('Reset')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: palette.onBackground.withValues(alpha: 0.15),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: ReflowText(
              document: preview,
              prefs: prefs,
              textColor: palette.onBackground,
            ),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Theme'),
          Wrap(
            spacing: 8,
            children: [
              for (final t in ReadingThemeId.values)
                ChoiceChip(
                  label: Text(t.label),
                  selected: prefs.themeId == t,
                  onSelected: (_) => c.setTheme(t),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Font'),
          Wrap(
            spacing: 8,
            children: [
              for (final f in ReadingFontFamily.values)
                ChoiceChip(
                  label: Text(f.label),
                  selected: prefs.fontFamily == f,
                  onSelected: (_) => c.setFont(f),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _SliderTile(
            label: 'Text size',
            value: prefs.fontSizeSp,
            min: 12,
            max: 40,
            divisions: 28,
            display: prefs.fontSizeSp.round().toString(),
            onChanged: c.setFontSize,
          ),
          _SliderTile(
            label: 'Letter spacing',
            value: prefs.letterSpacingEm,
            min: 0,
            max: 0.25,
            divisions: 25,
            display: prefs.letterSpacingEm.toStringAsFixed(2),
            onChanged: c.setLetterSpacing,
          ),
          _SliderTile(
            label: 'Word spacing',
            value: prefs.wordSpacingEm,
            min: 0,
            max: 0.5,
            divisions: 25,
            display: prefs.wordSpacingEm.toStringAsFixed(2),
            onChanged: c.setWordSpacing,
          ),
          _SliderTile(
            label: 'Line height',
            value: prefs.lineHeight,
            min: 1.0,
            max: 2.5,
            divisions: 30,
            display: '${prefs.lineHeight.toStringAsFixed(1)}×',
            onChanged: c.setLineHeight,
          ),
          _SliderTile(
            label: 'Paragraph spacing',
            value: prefs.paragraphSpacingEm,
            min: 0,
            max: 2.5,
            divisions: 25,
            display: '${prefs.paragraphSpacingEm.toStringAsFixed(1)}×',
            onChanged: c.setParagraphSpacing,
          ),
          _SliderTile(
            label: 'Line width',
            value: prefs.maxLineChars,
            min: 40,
            max: 90,
            divisions: 50,
            display: '${prefs.maxLineChars.round()} chars',
            onChanged: c.setMaxLineChars,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sentence pacing'),
            subtitle: const Text(
              'Show each sentence as its own spaced block for calmer pacing.',
            ),
            value: prefs.sentencePacing,
            onChanged: c.setSentencePacing,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bionic reading'),
            subtitle: const Text(
              'Bold the start of each word. Optional — limited evidence.',
            ),
            value: prefs.bionicEnabled,
            onChanged: c.setBionic,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(display, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
