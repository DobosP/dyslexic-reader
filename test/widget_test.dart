import 'package:dyslexic_reader/app/app.dart';
import 'package:dyslexic_reader/data/prefs/prefs_repository.dart';
import 'package:dyslexic_reader/domain/models/library_entry.dart';
import 'package:dyslexic_reader/features/library/library_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the library empty and platform-free in tests (no path_provider call).
class _EmptyLibrary extends LibraryController {
  @override
  Future<List<LibraryEntry>> build() async => <LibraryEntry>[];
}

void main() {
  testWidgets('app boots to the library screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryControllerProvider.overrideWith(_EmptyLibrary.new),
        ],
        child: const DyslexicReaderApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dyslexic Reader'), findsOneWidget);
    expect(find.text('Read the sample'), findsOneWidget);
    expect(find.text('Open a PDF or text file'), findsOneWidget);
  });
}
