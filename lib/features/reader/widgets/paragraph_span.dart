import 'package:flutter/widgets.dart';

import '../../../domain/models/reading_document.dart';
import '../../../domain/reflow/bionic.dart';

/// Builds the styled text span for a paragraph (or page fragment). Supports an
/// optional [bionic] prefix-bold, a read-along highlight over the character
/// range [highlightStart, highlightEnd), and a dotted underline over any
/// [noteRanges] (sentences the user has annotated).
InlineSpan buildParagraphSpan(
  List<Word> words,
  TextStyle base, {
  bool bionic = false,
  int highlightStart = -1,
  int highlightEnd = -1,
  Color? highlightColor,
  List<(int, int)> noteRanges = const [],
  Color? noteColor,
}) {
  final hasHighlight =
      highlightColor != null && highlightStart >= 0 && highlightEnd > highlightStart;
  final hasNotes = noteRanges.isNotEmpty;

  if (!bionic && !hasHighlight && !hasNotes) {
    return TextSpan(text: words.map((w) => w.text).join(' '), style: base);
  }

  bool inRange(Word w) => hasHighlight && w.start < highlightEnd && w.end > highlightStart;
  bool noted(Word w) =>
      hasNotes && noteRanges.any((r) => w.start < r.$2 && w.end > r.$1);

  TextStyle styleFor(Word w) {
    var s = base;
    if (inRange(w)) s = s.copyWith(backgroundColor: highlightColor);
    if (noted(w)) {
      s = s.copyWith(
        decoration: TextDecoration.underline,
        decorationColor: noteColor ?? base.color,
        decorationStyle: TextDecorationStyle.dotted,
        decorationThickness: 2,
      );
    }
    return s;
  }

  final spans = <InlineSpan>[];
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    final normal = styleFor(w);

    if (bionic) {
      final boldHi = normal.copyWith(fontWeight: FontWeight.w700);
      final n = Bionic.boldPrefixLength(w.text);
      if (n > 0) spans.add(TextSpan(text: w.text.substring(0, n), style: boldHi));
      if (n < w.text.length) spans.add(TextSpan(text: w.text.substring(n), style: normal));
    } else {
      spans.add(TextSpan(text: w.text, style: normal));
    }

    if (i != words.length - 1) {
      // Carry the read-along background across the inter-word space (keeps the
      // highlight continuous); the note underline stays on words only.
      final sepHi = inRange(w) && inRange(words[i + 1]);
      spans.add(TextSpan(
        text: ' ',
        style: sepHi ? base.copyWith(backgroundColor: highlightColor) : base,
      ));
    }
  }
  return TextSpan(style: base, children: spans);
}
