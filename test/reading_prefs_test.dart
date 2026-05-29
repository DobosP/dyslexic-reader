import 'package:dyslexic_reader/domain/models/reading_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('json round-trip preserves values', () {
    const p = ReadingPrefs(
      fontFamily: ReadingFontFamily.openDyslexic,
      themeId: ReadingThemeId.dark,
      fontSizeSp: 24,
      lineHeight: 1.8,
      bionicEnabled: true,
    );
    final back = ReadingPrefs.decode(p.encode());
    expect(back.fontFamily, ReadingFontFamily.openDyslexic);
    expect(back.themeId, ReadingThemeId.dark);
    expect(back.fontSizeSp, 24);
    expect(back.lineHeight, 1.8);
    expect(back.bionicEnabled, true);
  });

  test('fromJson tolerates missing keys and bad enum names', () {
    final p = ReadingPrefs.fromJson(const {
      'fontFamily': 'not-a-real-font',
      'themeId': 'cream',
    });
    const d = ReadingPrefs();
    expect(p.fontFamily, d.fontFamily); // fell back to default
    expect(p.themeId, ReadingThemeId.cream);
    expect(p.fontSizeSp, d.fontSizeSp);
  });

  test('copyWith changes only the targeted field', () {
    const p = ReadingPrefs();
    final q = p.copyWith(fontSizeSp: 30);
    expect(q.fontSizeSp, 30);
    expect(q.themeId, p.themeId);
    expect(q.fontFamily, p.fontFamily);
  });

  test('derived spacing scales with font size', () {
    const p = ReadingPrefs(fontSizeSp: 20, letterSpacingEm: 0.1);
    expect(p.letterSpacingPx, closeTo(2.0, 1e-9));
  });
}
