import 'package:dyslexic_reader/domain/reflow/text_cleanup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes ligatures, strips relic chars, collapses spaces', () {
    final out = TextCleanup.clean('oﬃce ﬁle �bad  spaced');
    expect(out.contains('ﬃ'), isFalse);
    expect(out.contains('ﬁ'), isFalse);
    expect(out.contains('�'), isFalse);
    expect(out.contains('  '), isFalse);
    expect(out.startsWith('office file'), isTrue);
  });

  test('folds full-width forms and normalizes unicode spaces', () {
    // Full-width "Hello", a non-breaking space, and an ideographic space.
    final out = TextCleanup.clean('Ｈｅｌｌｏ World　end');
    expect(out, 'Hello World end');
  });
}
