import 'package:flutter/widgets.dart';

import '../../../domain/models/reading_document.dart';
import '../../../domain/reflow/bionic.dart';

/// Builds the styled text span for a paragraph (or page fragment). Supports an
/// optional [bionic] prefix-bold, a read-along chunk highlight over the
/// character range [highlightStart, highlightEnd), a tighter current-word
/// highlight over [wordStart, wordEnd) (painted on top of the chunk band during
/// read-aloud), persistent manual [manualHighlightRanges], and a solid colored
/// underline + faint tint over any [noteRanges] (the exact words the user has
/// annotated, so the note's place is visible).
InlineSpan buildParagraphSpan(
  List<Word> words,
  TextStyle base, {
  bool bionic = false,
  int highlightStart = -1,
  int highlightEnd = -1,
  Color? highlightColor,
  int wordStart = -1,
  int wordEnd = -1,
  Color? wordColor,
  List<(int, int)> manualHighlightRanges = const [],
  Color? manualHighlightColor,
  List<(int, int)> noteRanges = const [],
  Color? noteColor,
}) {
  final hasHighlight =
      highlightColor != null &&
      highlightStart >= 0 &&
      highlightEnd > highlightStart;
  final hasWord = wordColor != null && wordStart >= 0 && wordEnd > wordStart;
  final hasManualHighlights = manualHighlightRanges.isNotEmpty;
  final hasNotes = noteRanges.isNotEmpty;

  if (!bionic &&
      !hasHighlight &&
      !hasWord &&
      !hasManualHighlights &&
      !hasNotes) {
    return TextSpan(text: words.map((w) => w.text).join(' '), style: base);
  }

  bool inRange(Word w) =>
      hasHighlight && w.start < highlightEnd && w.end > highlightStart;
  bool inWord(Word w) => hasWord && w.start < wordEnd && w.end > wordStart;
  bool manuallyHighlighted(Word w) =>
      hasManualHighlights &&
      manualHighlightRanges.any((r) => w.start < r.$2 && w.end > r.$1);
  bool noted(Word w) =>
      hasNotes && noteRanges.any((r) => w.start < r.$2 && w.end > r.$1);

  final noteTint = (noteColor ?? base.color)?.withValues(alpha: 0.14);
  final manualTint = manualHighlightColor ?? base.backgroundColor;

  TextStyle styleFor(Word w) {
    var s = base;
    if (manuallyHighlighted(w)) {
      s = s.copyWith(backgroundColor: manualTint);
    }
    // Notes sit underneath: a faint tint + solid underline that persists even
    // while the transient read-along highlight paints over the background.
    if (noted(w)) {
      s = s.copyWith(
        backgroundColor: noteTint,
        decoration: TextDecoration.underline,
        decorationColor: noteColor ?? base.color,
        decorationStyle: TextDecorationStyle.solid,
        decorationThickness: 2.5,
      );
    }
    if (inRange(w)) s = s.copyWith(backgroundColor: highlightColor);
    if (inWord(w)) s = s.copyWith(backgroundColor: wordColor);
    return s;
  }

  final spans = <InlineSpan>[];
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    final normal = styleFor(w);

    if (bionic) {
      final boldHi = normal.copyWith(fontWeight: FontWeight.w700);
      final n = Bionic.boldPrefixLength(w.text);
      if (n > 0) {
        spans.add(TextSpan(text: w.text.substring(0, n), style: boldHi));
      }
      if (n < w.text.length) {
        spans.add(TextSpan(text: w.text.substring(n), style: normal));
      }
    } else {
      spans.add(TextSpan(text: w.text, style: normal));
    }

    if (i != words.length - 1) {
      // Carry the note underline/tint and the read-along background across the
      // inter-word space so each stays continuous between adjacent words.
      final next = words[i + 1];
      var sep = base;
      if (manuallyHighlighted(w) && manuallyHighlighted(next)) {
        sep = sep.copyWith(backgroundColor: manualTint);
      }
      if (noted(w) && noted(next)) {
        sep = sep.copyWith(
          backgroundColor: noteTint,
          decoration: TextDecoration.underline,
          decorationColor: noteColor ?? base.color,
          decorationStyle: TextDecorationStyle.solid,
          decorationThickness: 2.5,
        );
      }
      if (inRange(w) && inRange(next)) {
        sep = sep.copyWith(backgroundColor: highlightColor);
      }
      spans.add(TextSpan(text: ' ', style: sep));
    }
  }
  return TextSpan(style: base, children: spans);
}
