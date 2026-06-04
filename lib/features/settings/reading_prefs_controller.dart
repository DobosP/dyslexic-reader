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
  void reset() => _update(const ReadingPrefs());
}

final readingPrefsProvider =
    NotifierProvider<ReadingPrefsController, ReadingPrefs>(
  ReadingPrefsController.new,
);
