import 'package:dyslexic_reader/domain/models/reading_document.dart';
import 'package:dyslexic_reader/domain/reflow/tokenizer.dart';
import 'package:dyslexic_reader/domain/structure/document_structure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final doc = Tokenizer.fromBlocks(const [
    TextBlock(role: BlockRole.h1, text: 'Chapter One'),
    TextBlock(role: BlockRole.body, text: 'Alpha beta. Gamma delta epsilon.'),
    TextBlock(role: BlockRole.h2, text: 'A Section'),
    TextBlock(role: BlockRole.body, text: 'One two three four.'),
  ]);

  test('outline lists headings with levels and offsets', () {
    final outline = DocumentStructure.outline(doc);
    expect(outline.length, 2);
    expect(outline[0].title, 'Chapter One');
    expect(outline[0].level, 1);
    expect(outline[1].title, 'A Section');
    expect(outline[1].level, 2);
    expect(
      doc.text.substring(outline[0].offset, outline[0].offset + 'Chapter One'.length),
      'Chapter One',
    );
  });

  test('stats count body sentences and average words per sentence', () {
    final stats = DocumentStructure.stats(doc);
    expect(stats.sentences, 3); // 2 body paragraphs → 3 sentences
    expect(stats.avgWordsPerSentence, closeTo(3.0, 1e-9)); // (2+3+4)/3
    expect(stats.words, 13); // incl. heading words
    expect(stats.readingMinutes, greaterThanOrEqualTo(1));
  });

  test('sentenceRefs lists headings + body sentences with paragraph ranges', () {
    final refs = DocumentStructure.sentenceRefs(doc);
    expect(refs.length, 5); // h1 + 2 + h2 + 1
    expect(refs.first.wordCount, 2); // "Chapter One"
    final s = refs[1];
    expect(s.paragraphStart <= s.start, true);
    expect(s.paragraphEnd >= s.end, true);
  });

  test('sentenceIndexAtOffset finds the sentence at an offset', () {
    final refs = DocumentStructure.sentenceRefs(doc);
    expect(DocumentStructure.sentenceIndexAtOffset(refs, 0), 0);
    final gamma = doc.text.indexOf('Gamma');
    final idx = DocumentStructure.sentenceIndexAtOffset(refs, gamma);
    expect(refs[idx].start <= gamma, true);
  });
}
