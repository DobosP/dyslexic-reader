import 'package:dyslexic_reader/domain/models/reading_document.dart';
import 'package:dyslexic_reader/features/reader/widgets/paragraph_span.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // "the lazy dog" with offsets matching a 0-based source string.
  const words = [
    Word(text: 'the', start: 0, end: 3),
    Word(text: 'lazy', start: 4, end: 8),
    Word(text: 'dog', start: 9, end: 12),
  ];
  const base = TextStyle(fontSize: 16);

  /// All leaf TextSpans with non-empty text, in order.
  List<TextSpan> leaves(InlineSpan span) {
    final out = <TextSpan>[];
    void walk(InlineSpan s) {
      if (s is TextSpan) {
        if ((s.text ?? '').isNotEmpty) out.add(s);
        for (final c in s.children ?? const <InlineSpan>[]) {
          walk(c);
        }
      }
    }

    walk(span);
    return out;
  }

  test('plain paragraph has no background', () {
    final span = buildParagraphSpan(words, base);
    expect((span as TextSpan).text, 'the lazy dog');
    expect(span.style?.backgroundColor, isNull);
  });

  test('chunk highlight tints the words in range', () {
    const band = Color(0x33112233);
    final span = buildParagraphSpan(
      words, base,
      highlightStart: 0, highlightEnd: 12, highlightColor: band,
    );
    final tinted = leaves(span).where((s) => s.style?.backgroundColor == band);
    expect(tinted, isNotEmpty);
  });

  test('word highlight paints only the current word on top of the band', () {
    const band = Color(0x33112233);
    const wordHi = Color(0xFFAA0000);
    // Highlight the middle word "lazy" (offsets 4..8).
    final span = buildParagraphSpan(
      words, base,
      highlightStart: 0, highlightEnd: 12, highlightColor: band,
      wordStart: 4, wordEnd: 8, wordColor: wordHi,
    );
    final wordLeaf =
        leaves(span).firstWhere((s) => s.text == 'lazy');
    expect(wordLeaf.style?.backgroundColor, wordHi);
    // "the" stays on the chunk band, not the word colour.
    final theLeaf = leaves(span).firstWhere((s) => s.text == 'the');
    expect(theLeaf.style?.backgroundColor, band);
  });
}
