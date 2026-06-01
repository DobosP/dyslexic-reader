import 'package:flutter/widgets.dart';

import '../../../domain/models/reading_document.dart';
import '../../../domain/reflow/bionic.dart';

/// Builds the styled text span for a paragraph (or page fragment). Supports an
/// optional [bionic] prefix-bold and an optional read-along sentence highlight
/// over the character range [highlightStart, highlightEnd).
InlineSpan buildParagraphSpan(
  List<Word> words,
  TextStyle base, {
  bool bionic = false,
  int highlightStart = -1,
  int highlightEnd = -1,
  Color? highlightColor,
}) {
  final hasHighlight =
      highlightColor != null && highlightStart >= 0 && highlightEnd > highlightStart;

  if (!bionic && !hasHighlight) {
    return TextSpan(text: words.map((w) => w.text).join(' '), style: base);
  }

  bool inRange(Word w) => hasHighlight && w.start < highlightEnd && w.end > highlightStart;
  final bold = base.copyWith(fontWeight: FontWeight.w700);
  final spans = <InlineSpan>[];

  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    final hi = inRange(w);
    final normal = hi ? base.copyWith(backgroundColor: highlightColor) : base;
    final boldHi = hi ? bold.copyWith(backgroundColor: highlightColor) : bold;

    if (bionic) {
      final n = Bionic.boldPrefixLength(w.text);
      if (n > 0) spans.add(TextSpan(text: w.text.substring(0, n), style: boldHi));
      if (n < w.text.length) spans.add(TextSpan(text: w.text.substring(n), style: normal));
    } else {
      spans.add(TextSpan(text: w.text, style: normal));
    }

    if (i != words.length - 1) {
      // Highlight the inter-word space too, so the sentence highlight is continuous.
      final sepHi = hi && inRange(words[i + 1]);
      spans.add(TextSpan(
        text: ' ',
        style: sepHi ? base.copyWith(backgroundColor: highlightColor) : base,
      ));
    }
  }
  return TextSpan(style: base, children: spans);
}
