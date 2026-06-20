import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/prefs_repository.dart';
import '../../domain/models/reading_prefs.dart';

/// Holds the current [ReadingPrefs] and persists every change. UI reads this
/// provider to restyle the reading surface live.
class ReadingPrefsController extends Notifier<ReadingPrefs> {
  @override
  ReadingPrefs build() => ref.watch(prefsRepositoryProvider).load();

  void _update(ReadingPrefs next) {
    state = next;
    ref.read(prefsRepositoryProvider).save(next);
  }

  void setFont(ReadingFontFamily v) => _update(state.copyWith(fontFamily: v));
  void setTheme(ReadingThemeId v) => _update(state.copyWith(themeId: v));
  void setFontSize(double v) => _update(state.copyWith(fontSizeSp: v));
  void setLetterSpacing(double v) => _update(state.copyWith(letterSpacingEm: v));
  void setWordSpacing(double v) => _update(state.copyWith(wordSpacingEm: v));
  void setLineHeight(double v) => _update(state.copyWith(lineHeight: v));
  void setParagraphSpacing(double v) =>
      _update(state.copyWith(paragraphSpacingEm: v));
  void setMaxLineChars(double v) => _update(state.copyWith(maxLineChars: v));
  void setBionic(bool v) => _update(state.copyWith(bionicEnabled: v));
  void setSentencePacing(bool v) => _update(state.copyWith(sentencePacing: v));
  void setReadingWpm(double v) => _update(state.copyWith(readingWpm: v));
  void setHighlightMaxRows(int v) =>
      _update(state.copyWith(highlightMaxRows: v));
  void setReaderContinuous(bool v) =>
      _update(state.copyWith(readerContinuous: v));
  void setLineHighlight(bool v) => _update(state.copyWith(lineHighlight: v));
  void setRulerStyle(ReadingRulerStyle v) =>
      _update(state.copyWith(rulerStyle: v));
  void setRulerRows(int v) => _update(state.copyWith(rulerRows: v));

  /// Unified "focus height" — keeps the highlight chunk size and the focus-band
  /// height in step, since they're one concept in the reading-focus UI.
  void setFocusRows(int v) =>
      _update(state.copyWith(highlightMaxRows: v, rulerRows: v));
  void setRulerCenter(double v) =>
      _update(state.copyWith(rulerCenter: v.clamp(0.08, 0.92)));
  void setTtsVoice(String? name, String? locale) => _update(
        name == null
            ? state.copyWith(clearTtsVoice: true)
            : state.copyWith(ttsVoiceName: name, ttsVoiceLocale: locale),
      );
  void setTtsPitch(double v) => _update(state.copyWith(ttsPitch: v.clamp(0.5, 2.0)));
  void reset() => _update(const ReadingPrefs());
}

final readingPrefsProvider =
    NotifierProvider<ReadingPrefsController, ReadingPrefs>(
  ReadingPrefsController.new,
);
