import 'package:dyslexic_reader/data/prefs/prefs_repository.dart';
import 'package:dyslexic_reader/domain/models/library_entry.dart';
import 'package:dyslexic_reader/domain/reflow/tokenizer.dart';
import 'package:dyslexic_reader/features/library/library_controller.dart';
import 'package:dyslexic_reader/features/reader/reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmptyLibrary extends LibraryController {
  @override
  Future<List<LibraryEntry>> build() async => <LibraryEntry>[];
}

void main() {
  testWidgets('in-document search finds matches and shows a count', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final doc = Tokenizer.parse(
      'The river flows fast. A river is wide. Down by the river we rest.',
      title: 'Test',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryControllerProvider.overrideWith(_EmptyLibrary.new),
        ],
        child: MaterialApp(home: ReaderScreen(document: doc)),
      ),
    );
    await tester.pumpAndSettle();

    // Open search from the app bar.
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'river');
    await tester.pumpAndSettle();

    // Three occurrences of "river"; first match selected.
    expect(find.text('1/3'), findsOneWidget);

    // Next match advances the counter.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
  });
}
