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
      sentencePacing: true,
      rulerStyle: ReadingRulerStyle.spotlight,
      rulerRows: 3,
      rulerCenter: 0.6,
      ttsVoiceName: 'en-us-x-sfg#male_1',
      ttsVoiceLocale: 'en-US',
      ttsPitch: 1.2,
    );
    final back = ReadingPrefs.decode(p.encode());
    expect(back.fontFamily, ReadingFontFamily.openDyslexic);
    expect(back.themeId, ReadingThemeId.dark);
    expect(back.fontSizeSp, 24);
    expect(back.lineHeight, 1.8);
    expect(back.bionicEnabled, true);
    expect(back.sentencePacing, true);
    expect(back.rulerStyle, ReadingRulerStyle.spotlight);
    expect(back.rulerRows, 3);
    expect(back.rulerCenter, 0.6);
    expect(back.ttsVoiceName, 'en-us-x-sfg#male_1');
    expect(back.ttsVoiceLocale, 'en-US');
    expect(back.ttsPitch, 1.2);
  });

  test('copyWith clears the TTS voice with clearTtsVoice', () {
    const p = ReadingPrefs(ttsVoiceName: 'v', ttsVoiceLocale: 'en-US');
    final cleared = p.copyWith(clearTtsVoice: true);
    expect(cleared.ttsVoiceName, isNull);
    expect(cleared.ttsVoiceLocale, isNull);
    // A normal copyWith keeps the voice.
    expect(p.copyWith(ttsPitch: 1.5).ttsVoiceName, 'v');
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
