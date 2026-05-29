import 'package:flutter/material.dart';

import '../../../domain/models/reading_document.dart';
import '../../../domain/models/reading_prefs.dart';
import 'paragraph_span.dart';

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
            buildParagraphSpan(
              document.paragraphs[i].words,
              base,
              bionic: prefs.bionicEnabled,
            ),
            textAlign: TextAlign.start,
          ),
        ),
      ),
    );
  }
}
