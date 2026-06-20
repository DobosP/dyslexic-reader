import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/reading_theme.dart';
import '../../domain/reflow/tokenizer.dart';
import '../../domain/models/reading_prefs.dart';
import '../reader/widgets/reflow_text.dart';
import 'about_screen.dart';
import 'reading_prefs_controller.dart';
import 'tts_voice_screen.dart';

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
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Text layout', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('In page')),
                    ButtonSegment(value: true, label: Text('Continuous')),
                  ],
                  selected: {prefs.readerContinuous},
                  onSelectionChanged: (s) => c.setReaderContinuous(s.first),
                  showSelectedIcon: false,
                ),
              ),
            ],
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
          const SizedBox(height: 16),
          const _SectionLabel('Reading focus'),
          Text(
            'One line-focus aid that follows your reading to keep your place. '
            '“Highlight line” tints the current sentence; the band styles dim or '
            'tint a focus strip the text flows under. Strong evidence for '
            'dyslexic readers.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final r in ReadingRulerStyle.values)
                ChoiceChip(
                  label: Text(r.label),
                  selected: prefs.rulerStyle == r,
                  onSelected: (_) => c.setRulerStyle(r),
                ),
            ],
          ),
          if (prefs.rulerStyle != ReadingRulerStyle.off) ...[
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Focus height', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 1, label: Text('1 line')),
                      ButtonSegment(value: 2, label: Text('2 lines')),
                      ButtonSegment(value: 3, label: Text('3 lines')),
                    ],
                    selected: {prefs.rulerRows.clamp(1, 3)},
                    onSelectionChanged: (s) => c.setFocusRows(s.first),
                    showSelectedIcon: false,
                  ),
                ),
              ],
            ),
          ],
          if (prefs.rulerStyle.isBand) ...[
            const SizedBox(height: 8),
            _SliderTile(
              label: 'Band position',
              value: prefs.rulerCenter,
              min: 0.15,
              max: 0.85,
              divisions: 14,
              display: '${(prefs.rulerCenter * 100).round()}%',
              onChanged: c.setRulerCenter,
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sentence pacing'),
            subtitle: const Text(
              'Show each sentence as its own spaced block for calmer pacing.',
            ),
            value: prefs.sentencePacing,
            onChanged: c.setSentencePacing,
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Read aloud'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.record_voice_over_outlined),
            title: const Text('Voice'),
            subtitle: Text(prefs.ttsVoiceName ?? 'Device default'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TtsVoiceScreen()),
            ),
          ),
          _SliderTile(
            label: 'Voice pitch',
            value: prefs.ttsPitch,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            display: '${prefs.ttsPitch.toStringAsFixed(1)}×',
            onChanged: c.setTtsPitch,
          ),
          _SliderTile(
            label: 'Read-along pace',
            value: prefs.readingWpm,
            min: 60,
            max: 400,
            divisions: 34,
            display: '${prefs.readingWpm.round()} wpm',
            onChanged: c.setReadingWpm,
          ),
          const SizedBox(height: 8),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('About Dyslexic Reader'),
            subtitle: const Text('Privacy, licenses, feedback'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
            ),
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
