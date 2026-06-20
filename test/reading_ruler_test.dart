import 'package:dyslexic_reader/app/theme/reading_theme.dart';
import 'package:dyslexic_reader/domain/models/reading_prefs.dart';
import 'package:dyslexic_reader/features/reader/widgets/reading_ruler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final palette = paletteFor(ReadingThemeId.cream);

  Widget host(ReadingRulerStyle style) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 800,
          child: ReadingRulerOverlay(
            style: style,
            palette: palette,
            bandHeight: 60,
            center: 0.45,
          ),
        ),
      ),
    );
  }

  // The band layers are painted ColoredBoxes inside the overlay.
  Finder bandLayers() => find.descendant(
        of: find.byType(ReadingRulerOverlay),
        matching: find.byType(ColoredBox),
      );

  testWidgets('off paints no band', (tester) async {
    await tester.pumpWidget(host(ReadingRulerStyle.off));
    expect(bandLayers(), findsNothing);
  });

  testWidgets('highlight is handled in-text, not as a band overlay',
      (tester) async {
    await tester.pumpWidget(host(ReadingRulerStyle.highlight));
    expect(bandLayers(), findsNothing);
  });

  for (final style in [
    ReadingRulerStyle.bar,
    ReadingRulerStyle.underline,
    ReadingRulerStyle.shade,
    ReadingRulerStyle.spotlight,
  ]) {
    testWidgets('$style paints a focus band (auto-positioned, no drag grip)',
        (tester) async {
      await tester.pumpWidget(host(style));
      expect(tester.takeException(), isNull);
      expect(bandLayers(), findsWidgets);
      // The band auto-follows reading now; there is no draggable grip.
      expect(find.byIcon(Icons.drag_indicator), findsNothing);
    });
  }

  test('isBand classifies only the band styles', () {
    expect(ReadingRulerStyle.off.isBand, isFalse);
    expect(ReadingRulerStyle.highlight.isBand, isFalse);
    expect(ReadingRulerStyle.bar.isBand, isTrue);
    expect(ReadingRulerStyle.underline.isBand, isTrue);
    expect(ReadingRulerStyle.shade.isBand, isTrue);
    expect(ReadingRulerStyle.spotlight.isBand, isTrue);
  });
}
