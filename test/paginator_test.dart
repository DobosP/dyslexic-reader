import 'package:dyslexic_reader/domain/models/reading_document.dart';
import 'package:dyslexic_reader/domain/reflow/paginator.dart';
import 'package:dyslexic_reader/domain/reflow/tokenizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Fake measure: 1 height unit per character (role ignored for the test).
  double measure(String t, BlockRole role) => t.length.toDouble();

  test('packs words into pages that fit the height budget', () {
    final doc = Tokenizer.parse('aaa bbb ccc ddd eee fff');
    final pages =
        Paginator.paginate(doc: doc, maxHeight: 11, paragraphSpacing: 0, measure: measure);
    expect(pages.length, 2);
    expect(pages.first.paragraphs.single.text, 'aaa bbb ccc');
    expect(pages.last.paragraphs.single.text, 'ddd eee fff');
  });

  test('splits a long paragraph across pages, preserving order and offsets', () {
    final doc = Tokenizer.parse('one two three four five six seven');
    final pages =
        Paginator.paginate(doc: doc, maxHeight: 9, paragraphSpacing: 0, measure: measure);
    final words = <String>[];
    for (final p in pages) {
      for (final frag in p.paragraphs) {
        for (final w in frag.words) {
          words.add(w.text);
          expect(doc.text.substring(w.start, w.end), w.text);
        }
      }
    }
    expect(words, ['one', 'two', 'three', 'four', 'five', 'six', 'seven']);
  });

  test('paragraph spacing can force a break between paragraphs', () {
    final doc = Tokenizer.parse('aaa\n\nbbb\n\nccc');
    final pages =
        Paginator.paginate(doc: doc, maxHeight: 7, paragraphSpacing: 5, measure: measure);
    expect(pages.length, 3);
  });

  test('pageForOffset returns the page starting at or before the offset', () {
    final doc = Tokenizer.parse('aaa bbb ccc ddd');
    final pages =
        Paginator.paginate(doc: doc, maxHeight: 7, paragraphSpacing: 0, measure: measure);
    expect(Paginator.pageForOffset(pages, 0), 0);
    expect(Paginator.pageForOffset(pages, doc.text.indexOf('ccc')), 1);
  });

  test('preserves block roles on page paragraphs', () {
    final doc = Tokenizer.fromBlocks(const [
      TextBlock(role: BlockRole.h1, text: 'Chapter One'),
      TextBlock(role: BlockRole.body, text: 'Body text here.'),
    ]);
    final pages =
        Paginator.paginate(doc: doc, maxHeight: 1000, paragraphSpacing: 4, measure: measure);
    final roles = [
      for (final p in pages)
        for (final frag in p.paragraphs) frag.role,
    ];
    expect(roles.first, BlockRole.h1);
    expect(roles.last, BlockRole.body);
  });

  // Adversarial inputs the audit flagged as a possible RangeError. Each must
  // paginate without throwing.
  test('does not crash on a word taller than the page (forced single-word page)', () {
    final doc = Tokenizer.parse('supercalifragilisticexpialidocious tiny a');
    // maxHeight=1 is smaller than every word's measured height.
    final pages =
        Paginator.paginate(doc: doc, maxHeight: 1, paragraphSpacing: 0, measure: measure);
    final words = [
      for (final p in pages)
        for (final frag in p.paragraphs)
          for (final w in frag.words) w.text,
    ];
    expect(words, ['supercalifragilisticexpialidocious', 'tiny', 'a']);
  });

  test('does not crash on empty / whitespace-only documents', () {
    for (final src in ['', '   \n\n  ', '\n']) {
      final pages =
          Paginator.paginate(doc: Tokenizer.parse(src), maxHeight: 10, paragraphSpacing: 0, measure: measure);
      expect(pages, isNotEmpty); // always at least one (possibly empty) page
    }
  });

  test('does not crash with zero or negative height budget', () {
    final doc = Tokenizer.parse('alpha beta gamma');
    for (final h in [0.0, -5.0]) {
      final pages =
          Paginator.paginate(doc: doc, maxHeight: h, paragraphSpacing: 0, measure: measure);
      final words = [
        for (final p in pages)
          for (final frag in p.paragraphs)
            for (final w in frag.words) w.text,
      ];
      expect(words, ['alpha', 'beta', 'gamma']);
    }
  });

  test('LazyPaginator yields pages incrementally and reports completion', () {
    final doc = Tokenizer.parse('aaa bbb ccc ddd eee fff');
    final lp = LazyPaginator(doc: doc, maxHeight: 11, paragraphSpacing: 0, measure: measure);
    expect(lp.hasMore, true);
    expect(lp.next()!.paragraphs.single.text, 'aaa bbb ccc');
    expect(lp.hasMore, true);
    expect(lp.next()!.paragraphs.single.text, 'ddd eee fff');
    expect(lp.hasMore, false);
    expect(lp.next(), isNull);
  });
}
