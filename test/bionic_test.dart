import 'package:dyslexic_reader/domain/reflow/bionic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bold prefix length scales ~40% with word length', () {
    expect(Bionic.boldPrefixLength('a'), 1);
    expect(Bionic.boldPrefixLength('the'), 1);
    expect(Bionic.boldPrefixLength('reading'), 3);
    expect(Bionic.boldPrefixLength('comprehension'), 5);
  });

  test('always at least 1 and never exceeds word length', () {
    expect(Bionic.boldPrefixLength('I'), 1);
    expect(Bionic.boldPrefixLength('to'), inInclusiveRange(1, 2));
    expect(Bionic.boldPrefixLength(''), 0);
  });
}
