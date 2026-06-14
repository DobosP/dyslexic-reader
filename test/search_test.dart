import 'package:dyslexic_reader/domain/search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const text = 'The fox and the Fox saw another FOX. Foxes everywhere.';

  test('finds all case-insensitive occurrences in order', () {
    final m = findMatches(text, 'fox');
    // "fox" (4), "Fox" (16), "FOX" (32), "Fox" in "Foxes" (37)
    expect(m, [4, 16, 32, 37]);
  });

  test('ignores queries shorter than two characters', () {
    expect(findMatches(text, 'f'), isEmpty);
    expect(findMatches(text, ' '), isEmpty);
    expect(findMatches(text, ''), isEmpty);
  });

  test('returns empty when nothing matches', () {
    expect(findMatches(text, 'zebra'), isEmpty);
  });

  test('non-overlapping matches', () {
    expect(findMatches('aaaa', 'aa'), [0, 2]);
  });

  test('respects the cap', () {
    final big = 'ab' * 5000;
    expect(findMatches(big, 'ab', cap: 10).length, 10);
  });

  test('trims the query', () {
    expect(findMatches('hello world', '  world  '), [6]);
  });
}
