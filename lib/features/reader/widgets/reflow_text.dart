import 'package:flutter/material.dart';

import '../../../domain/models/reading_document.dart';
import '../../../domain/models/reading_prefs.dart';
import '../../../domain/reflow/bionic.dart';

/// Renders a [ReadingDocument] as a reflowed, left-aligned column of paragraphs
/// styled by [prefs]. Virtualized (one paragraph per list item) so large
/// documents stay smooth.
class ReflowText extends StatelessWidget {
  const ReflowText({
    super.key,
    required this.document,
    required this.prefs,
    required this.textColor,
    this.controller,
  });

  final ReadingDocument document;
  final ReadingPrefs prefs;
  final Color textColor;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: prefs.fontFamily.family,
      fontSize: prefs.fontSizeSp,
      height: prefs.lineHeight,
      letterSpacing: prefs.letterSpacingPx,
      wordSpacing: prefs.wordSpacingPx,
      color: textColor,
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: prefs.maxLineWidthPx),
        child: ListView.separated(
          controller: controller,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          itemCount: document.paragraphs.length,
          separatorBuilder: (_, _) =>
              SizedBox(height: prefs.paragraphSpacingPx),
          itemBuilder: (context, i) => Text.rich(
            _paragraphSpan(document.paragraphs[i], base),
            textAlign: TextAlign.start,
          ),
        ),
      ),
    );
  }

  InlineSpan _paragraphSpan(Paragraph p, TextStyle base) {
    if (!prefs.bionicEnabled) {
      return TextSpan(text: p.words.map((w) => w.text).join(' '), style: base);
    }
    final bold = base.copyWith(fontWeight: FontWeight.w700);
    final spans = <InlineSpan>[];
    for (var i = 0; i < p.words.length; i++) {
      final w = p.words[i].text;
      final n = Bionic.boldPrefixLength(w);
      if (n > 0) spans.add(TextSpan(text: w.substring(0, n), style: bold));
      if (n < w.length) spans.add(TextSpan(text: w.substring(n)));
      if (i != p.words.length - 1) spans.add(const TextSpan(text: ' '));
    }
    return TextSpan(style: base, children: spans);
  }
}
