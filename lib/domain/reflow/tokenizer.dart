import '../models/reading_document.dart';

/// Turns raw text into a [ReadingDocument]: blank-line-separated blocks become
/// paragraphs, and soft (single) line breaks inside a block are treated as
/// whitespace so the text reflows cleanly. Word character offsets into the
/// original text are preserved.
class Tokenizer {
  Tokenizer._();

  static final RegExp _paragraphBreak = RegExp(r'\n[ \t]*\n+');
  static final RegExp _word = RegExp(r'\S+');

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
