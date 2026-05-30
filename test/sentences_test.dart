import 'package:dyslexic_reader/domain/models/reading_document.dart';
import 'package:dyslexic_reader/domain/reflow/sentences.dart';
import 'package:dyslexic_reader/domain/reflow/tokenizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('splits a paragraph into sentences on . ! ?', () {
    final doc = Tokenizer.parse('First sentence. Second one! A third?');
    final sentences = Sentences.split(doc.paragraphs.single.words);
    expect(sentences.length, 3);
    expect(sentences[0].map((w) => w.text).join(' '), 'First sentence.');
    expect(sentences[1].map((w) => w.text).join(' '), 'Second one!');
    expect(sentences[2].map((w) => w.text).join(' '), 'A third?');
  });

  test('splitDocument makes one paragraph per sentence, keeps headings & offsets', () {
    final doc = Tokenizer.fromBlocks(const [
      TextBlock(role: BlockRole.h1, text: 'Title'),
      TextBlock(role: BlockRole.body, text: 'One. Two. Three.'),
    ]);
    final split = Sentences.splitDocument(doc);
    expect(split.paragraphs.length, 4); // heading + 3 sentences
    expect(split.paragraphs.first.role, BlockRole.h1);
    expect(split.paragraphs[1].words.map((w) => w.text).join(' '), 'One.');
    final s = split.paragraphs[2];
    expect(split.text.substring(s.start, s.end), 'Two.');
  });

  test('text without terminal punctuation is one sentence', () {
    final doc = Tokenizer.parse('No terminal punctuation here');
    expect(Sentences.split(doc.paragraphs.single.words).length, 1);
  });
}
