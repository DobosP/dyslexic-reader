import 'package:dyslexic_reader/app/theme/reading_theme.dart';
import 'package:dyslexic_reader/domain/models/reading_prefs.dart';
import 'package:dyslexic_reader/features/reader/widgets/reading_ruler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final palette = paletteFor(ReadingThemeId.cream);

  Widget host(ReadingRulerStyle style, {required ValueChanged<double> onChanged}) {
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
            onCenterChanged: onChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('off style renders nothing interactive', (tester) async {
    await tester.pumpWidget(host(ReadingRulerStyle.off, onChanged: (_) {}));
    expect(find.byIcon(Icons.drag_indicator), findsNothing);
  });

  for (final style in [
    ReadingRulerStyle.bar,
    ReadingRulerStyle.underline,
    ReadingRulerStyle.shade,
    ReadingRulerStyle.spotlight,
  ]) {
    testWidgets('$style builds with a draggable grip', (tester) async {
      await tester.pumpWidget(host(style, onChanged: (_) {}));
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
    });
  }

  testWidgets('dragging the grip reports a new centre on release', (tester) async {
    double? reported;
    await tester.pumpWidget(
      host(ReadingRulerStyle.bar, onChanged: (v) => reported = v),
    );
    await tester.drag(find.byIcon(Icons.drag_indicator), const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(reported, isNotNull);
    expect(reported, greaterThan(0.45)); // moved down
  });
}
