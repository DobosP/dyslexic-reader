import '../models/reading_document.dart';

/// Sentence segmentation + a document transform that turns each body paragraph
/// into one paragraph per sentence (for "sentence pacing"). Heuristic but cheap
/// and offset-preserving.
class Sentences {
  Sentences._();

  // A word ends a sentence if it ends with . ! or ? (allowing trailing quotes
  // or closing brackets). Abbreviations/decimals are over-counted — acceptable.
  static final RegExp _end = RegExp(r'[.!?]["”’)\]]*$');

  static bool endsSentence(String word) => _end.hasMatch(word);

  /// Group [words] into sentences (each a list of words, in order).
  static List<List<Word>> split(List<Word> words) {
    final sentences = <List<Word>>[];
    var cur = <Word>[];
    for (final w in words) {
      cur.add(w);
      if (endsSentence(w.text)) {
        sentences.add(cur);
        cur = <Word>[];
      }
    }
    if (cur.isNotEmpty) sentences.add(cur);
    return sentences;
  }

  /// Returns a document where each body paragraph is split into one paragraph
  /// per sentence (headings untouched). Character offsets are preserved.
  static ReadingDocument splitDocument(ReadingDocument doc) {
    final paragraphs = <Paragraph>[];
    for (final p in doc.paragraphs) {
      if (p.role != BlockRole.body) {
        paragraphs.add(p);
        continue;
      }
      for (final sentence in split(p.words)) {
        if (sentence.isEmpty) continue;
        paragraphs.add(Paragraph(
          words: sentence,
          start: sentence.first.start,
          end: sentence.last.end,
          role: BlockRole.body,
        ));
      }
    }
    return ReadingDocument(title: doc.title, text: doc.text, paragraphs: paragraphs);
  }
}
