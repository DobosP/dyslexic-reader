import '../models/reading_document.dart';

/// Turns raw text or typed [TextBlock]s into a [ReadingDocument].
class Tokenizer {
  Tokenizer._();

  static final RegExp _paragraphBreak = RegExp(r'\n[ \t]*\n+');
  static final RegExp _word = RegExp(r'\S+');

  /// Plain text → document. Blank-line-separated blocks become body paragraphs;
  /// soft (single) line breaks within a block are treated as whitespace.
  static ReadingDocument parse(String raw, {String title = 'Untitled'}) {
    final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final paragraphs = <Paragraph>[];

    var cursor = 0;
    final ranges = <List<int>>[];
    for (final m in _paragraphBreak.allMatches(text)) {
      ranges.add([cursor, m.start]);
      cursor = m.end;
    }
    ranges.add([cursor, text.length]);

    for (final r in ranges) {
      final words = _wordsIn(text, r[0], r[1]);
      if (words.isNotEmpty) {
        paragraphs.add(Paragraph(words: words, start: r[0], end: r[1]));
      }
    }
    return ReadingDocument(title: title, text: text, paragraphs: paragraphs);
  }

  /// Typed blocks (e.g. from the PDF structured extractor) → document, keeping
  /// each block's [BlockRole] so headings can be styled.
  static ReadingDocument fromBlocks(List<TextBlock> blocks, {String title = 'Untitled'}) {
    final buffer = StringBuffer();
    final ranges = <List<int>>[];
    for (var i = 0; i < blocks.length; i++) {
      if (i > 0) buffer.write('\n\n');
      final start = buffer.length;
      buffer.write(blocks[i].text);
      ranges.add([start, buffer.length]);
    }
    final text = buffer.toString();

    final paragraphs = <Paragraph>[];
    for (var i = 0; i < blocks.length; i++) {
      final words = _wordsIn(text, ranges[i][0], ranges[i][1]);
      if (words.isNotEmpty) {
        paragraphs.add(Paragraph(
          words: words,
          start: ranges[i][0],
          end: ranges[i][1],
          role: blocks[i].role,
        ));
      }
    }
    return ReadingDocument(title: title, text: text, paragraphs: paragraphs);
  }

  /// Split plain text into body blocks (for caching/uniform handling).
  static List<TextBlock> blocksFromText(String raw) {
    final doc = parse(raw);
    return [
      for (final p in doc.paragraphs)
        TextBlock(role: BlockRole.body, text: doc.text.substring(p.start, p.end)),
    ];
  }

  static List<Word> _wordsIn(String text, int start, int end) {
    final slice = text.substring(start, end);
    final words = <Word>[];
    for (final m in _word.allMatches(slice)) {
      words.add(Word(
        text: m.group(0)!,
        start: start + m.start,
        end: start + m.end,
      ));
    }
    return words;
  }
}
