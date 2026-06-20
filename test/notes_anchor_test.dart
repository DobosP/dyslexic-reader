import 'package:dyslexic_reader/data/prefs/prefs_repository.dart';
import 'package:dyslexic_reader/domain/models/library_entry.dart';
import 'package:dyslexic_reader/domain/reflow/tokenizer.dart';
import 'package:dyslexic_reader/features/library/library_controller.dart';
import 'package:dyslexic_reader/features/reader/reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A library holding a single document with a pre-existing note.
class _OneDocLibrary extends LibraryController {
  _OneDocLibrary(this._entry);
  final LibraryEntry _entry;
  @override
  Future<List<LibraryEntry>> build() async => [_entry];
}

void main() {
  testWidgets('an anchored note shows a margin marker on its line',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final doc = Tokenizer.parse(
      'The quick brown fox jumps over the lazy dog.',
      title: 'Test',
    );
    // "quick brown" sits at offsets 4..15 in the source string.
    final entry = LibraryEntry(
      id: 'e1',
      title: 'Test',
      source: DocSource.pasted,
      cacheBlocksPath: '',
      wordCount: 9,
      pageCount: 1,
      importedAt: DateTime(2020),
      notes: [
        Note(
          start: 4,
          end: 15,
          text: 'note on quick brown',
          createdAt: DateTime(2020),
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryControllerProvider.overrideWith(() => _OneDocLibrary(entry)),
      ],
      child: MaterialApp(home: ReaderScreen(document: doc, entry: entry)),
    ));
    await tester.pumpAndSettle();

    // The note is marked in the margin so its place in the text is visible.
    expect(find.byIcon(Icons.sticky_note_2), findsOneWidget);
  });
}
