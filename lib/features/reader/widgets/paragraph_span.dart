import 'package:flutter/widgets.dart';

import '../../../domain/models/reading_document.dart';
import '../../../domain/reflow/bionic.dart';

/// Builds the styled text span for a paragraph (or page fragment). When [bionic]
/// is on, the leading letters of each word are bolded; otherwise the whole run
/// is a single span (fast path).
InlineSpan buildParagraphSpan(
  List<Word> words,
  TextStyle base, {
  bool bionic = false,
}) {
  if (!bionic) {
    return TextSpan(text: words.map((w) => w.text).join(' '), style: base);
  }
  final bold = base.copyWith(fontWeight: FontWeight.w700);
  final spans = <InlineSpan>[];
  for (var i = 0; i < words.length; i++) {
    final w = words[i].text;
    final n = Bionic.boldPrefixLength(w);
    if (n > 0) spans.add(TextSpan(text: w.substring(0, n), style: bold));
    if (n < w.length) spans.add(TextSpan(text: w.substring(n)));
    if (i != words.length - 1) spans.add(const TextSpan(text: ' '));
  }
  return TextSpan(style: base, children: spans);
}
