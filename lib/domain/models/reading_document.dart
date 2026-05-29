/// A document prepared for the reading surface: a title plus the original
/// [text] split into [paragraphs] of [Word] tokens.
///
/// Each [Word] keeps its character offsets into [text]. They are unused by the
/// plain-text reflow today, but are the anchor we will map text-to-speech
/// `onRangeStart` callbacks onto when read-aloud lands (see docs/ARCHITECTURE.md).
class ReadingDocument {
  const ReadingDocument({
    required this.title,
    required this.text,
    required this.paragraphs,
  });

  final String title;
  final String text;
  final List<Paragraph> paragraphs;

  int get wordCount =>
      paragraphs.fold(0, (sum, p) => sum + p.words.length);
}

class Paragraph {
  const Paragraph({
    required this.words,
    required this.start,
    required this.end,
  });

  final List<Word> words;

  /// Character offsets into [ReadingDocument.text] (inclusive start, exclusive end).
  final int start;
  final int end;
}

class Word {
  const Word({
    required this.text,
    required this.start,
    required this.end,
  });

  final String text;

  /// Character offsets into [ReadingDocument.text].
  final int start;
  final int end;
}
