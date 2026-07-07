import 'package:dyslexic_reader/data/prefs/prefs_repository.dart';
import 'package:dyslexic_reader/domain/models/library_entry.dart';
import 'package:dyslexic_reader/domain/models/reading_document.dart';
import 'package:dyslexic_reader/domain/reflow/tokenizer.dart';
import 'package:dyslexic_reader/features/library/library_controller.dart';
import 'package:dyslexic_reader/features/library/library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LibraryHarness extends LibraryController {
  _LibraryHarness(this.entries, this.docs);

  List<LibraryEntry> entries;
  final Map<String, ReadingDocument> docs;

  @override
  Future<List<LibraryEntry>> build() async => entries;

  @override
  Future<ReadingDocument> open(LibraryEntry entry) async => docs[entry.id]!;

  @override
  Future<void> delete(LibraryEntry entry) async {
    entries = entries.where((e) => e.id != entry.id).toList();
    state = AsyncData(entries);
  }
}

void main() {
  testWidgets(
    'wide library clears the detail pane when selected entry is removed',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = _entry('one', 'Doc One');
      final second = _entry('two', 'Doc Two');
      late _LibraryHarness controller;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryControllerProvider.overrideWith(() {
              controller = _LibraryHarness(
                [first, second],
                {
                  first.id: Tokenizer.parse(
                    'Alpha content for the first document.',
                    title: first.title,
                  ),
                  second.id: Tokenizer.parse(
                    'Beta content for the second document.',
                    title: second.title,
                  ),
                },
              );
              return controller;
            }),
          ],
          child: const MaterialApp(home: LibraryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Doc One'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Alpha content', findRichText: true),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Options').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(controller.entries.map((e) => e.id), ['two']);
      expect(find.text('Doc One'), findsNothing);
      expect(find.text('Select a document to start reading'), findsOneWidget);
    },
  );
}

LibraryEntry _entry(String id, String title) {
  return LibraryEntry(
    id: id,
    title: title,
    source: DocSource.pasted,
    cacheBlocksPath: '',
    wordCount: 6,
    pageCount: 1,
    importedAt: DateTime(2026, 7, 7),
  );
}
