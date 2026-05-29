import 'package:dyslexic_reader/domain/reflow/tokenizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('splits paragraphs on blank lines', () {
    const raw = 'First para line one.\nStill first.\n\nSecond para here.';
    final doc = Tokenizer.parse(raw, title: 'T');
    expect(doc.paragraphs.length, 2);
    expect(doc.paragraphs.first.words.first.text, 'First');
    expect(doc.paragraphs.last.words.first.text, 'Second');
  });

  test('soft single line breaks stay within one paragraph', () {
    const raw = 'line one\nline two\nline three';
    final doc = Tokenizer.parse(raw);
    expect(doc.paragraphs.length, 1);
    expect(doc.paragraphs.first.words.length, 6);
  });

  test('word offsets map back to the source text', () {
    const raw = 'Hello brave new world.\n\nAnother paragraph, indeed.';
    final doc = Tokenizer.parse(raw);
    for (final p in doc.paragraphs) {
      for (final w in p.words) {
        expect(doc.text.substring(w.start, w.end), w.text);
      }
    }
  });

  test('blank/whitespace-only input yields no paragraphs', () {
    final doc = Tokenizer.parse('   \n  \n\t\n  ');
    expect(doc.paragraphs, isEmpty);
    expect(doc.wordCount, 0);
  });

  test('normalizes CRLF line endings', () {
    final doc = Tokenizer.parse('a b\r\n\r\nc d');
    expect(doc.paragraphs.length, 2);
  });
}
