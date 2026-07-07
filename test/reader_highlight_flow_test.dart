import 'package:dyslexic_reader/data/prefs/prefs_repository.dart';
import 'package:dyslexic_reader/domain/models/library_entry.dart';
import 'package:dyslexic_reader/domain/reflow/tokenizer.dart';
import 'package:dyslexic_reader/features/library/library_controller.dart';
import 'package:dyslexic_reader/features/reader/reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _HighlightLibrary extends LibraryController {
  _HighlightLibrary(this.entries);

  List<LibraryEntry> entries;

  @override
  Future<List<LibraryEntry>> build() async => entries;

  @override
  Future<void> saveProgress(String id, int charOffset) async {}

  @override
  Future<void> saveTtsPosition(String id, int charOffset) async {}

  @override
  Future<void> upsertHighlight(String id, TextHighlight highlight) async {
    entries = [
      for (final entry in entries)
        if (entry.id == id)
          entry.copyWith(
            highlights: [
              ...entry.highlights.where(
                (h) => h.start != highlight.start || h.end != highlight.end,
              ),
              highlight,
            ]..sort((a, b) => a.start.compareTo(b.start)),
          )
        else
          entry,
    ];
    state = AsyncData(entries);
  }

  @override
  Future<void> removeHighlight(String id, TextHighlight highlight) async {
    entries = [
      for (final entry in entries)
        if (entry.id == id)
          entry.copyWith(
            highlights: entry.highlights
                .where(
                  (h) => h.start != highlight.start || h.end != highlight.end,
                )
                .toList(),
          )
        else
          entry,
    ];
    state = AsyncData(entries);
  }
}

void main() {
  Future<_HighlightLibrary> pumpReader(
    WidgetTester tester, {
    required String text,
    required LibraryEntry entry,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final doc = Tokenizer.parse(text, title: entry.title);
    late _HighlightLibrary controller;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryControllerProvider.overrideWith(() {
            controller = _HighlightLibrary([entry]);
            return controller;
          }),
        ],
        child: MaterialApp(home: ReaderScreen(document: doc, entry: entry)),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  LibraryEntry entry({List<TextHighlight> highlights = const []}) {
    return LibraryEntry(
      id: 'doc',
      title: 'Highlight test',
      source: DocSource.pasted,
      cacheBlocksPath: '',
      wordCount: 9,
      pageCount: 1,
      importedAt: DateTime(2026, 7, 7),
      highlights: highlights,
    );
  }

  testWidgets('long-press text action saves a highlight range', (tester) async {
    final controller = await pumpReader(
      tester,
      text: 'The quick brown fox jumps. The second sentence follows.',
      entry: entry(),
    );

    final paragraph = find.textContaining(
      'The quick brown fox jumps.',
      findRichText: true,
    );
    expect(paragraph, findsOneWidget);

    await tester.longPress(paragraph);
    await tester.pumpAndSettle();
    expect(find.text('Highlight text'), findsOneWidget);

    await tester.tap(find.text('Highlight text'));
    await tester.pumpAndSettle();

    expect(controller.entries.single.highlights, hasLength(1));
    expect(controller.entries.single.highlights.single.start, 0);
    expect(controller.entries.single.highlights.single.end, 26);
    expect(find.text('Highlight saved'), findsOneWidget);
  });

  testWidgets('current-position highlight repaints, lists, and deletes',
      (tester) async {
    final controller = await pumpReader(
      tester,
      text: 'The quick brown fox jumps. The second sentence follows.',
      entry: entry(),
    );

    await tester.tap(find.byTooltip('Notes, bookmarks & highlights'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Highlight current line'));
    await tester.pumpAndSettle();

    expect(controller.entries.single.highlights, hasLength(1));
    expect(_hasManualHighlightPaint(tester), isTrue);

    await tester.tap(find.byTooltip('Notes, bookmarks & highlights'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View highlights'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('The quick brown', findRichText: true),
      findsWidgets,
    );

    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();

    expect(controller.entries.single.highlights, isEmpty);
    expect(
      find.text('No highlights yet. Long-press text to save one.'),
      findsOneWidget,
    );
  });
}

bool _hasManualHighlightPaint(WidgetTester tester) {
  for (final element in find.byType(RichText).evaluate()) {
    final richText = element.widget as RichText;
    if (_spanHasBackground(richText.text)) return true;
  }
  return false;
}

bool _spanHasBackground(InlineSpan span) {
  if (span is TextSpan) {
    if ((span.text ?? '').trim().isNotEmpty &&
        span.style?.backgroundColor != null) {
      return true;
    }
    final children = span.children;
    if (children != null && children.any(_spanHasBackground)) return true;
  }
  return false;
}
