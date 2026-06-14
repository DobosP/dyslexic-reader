import 'package:flutter/widgets.dart';

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

Widget _app(SharedPreferences prefs) => ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryControllerProvider.overrideWith(_EmptyLibrary.new),
      ],
      child: const DyslexicReaderApp(),
    );

void main() {
  testWidgets('app boots to the library screen once onboarded', (tester) async {
    // Pretend onboarding was already completed.
    SharedPreferences.setMockInitialValues({'onboarding_seen_v1': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_app(prefs));
    await tester.pumpAndSettle();

    expect(find.text('Dyslexic Reader'), findsOneWidget);
    expect(find.text('Read the sample'), findsOneWidget);
    expect(find.text('Open a document'), findsOneWidget);
  });

  testWidgets('first run shows onboarding, then Skip reaches the library',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_app(prefs));
    await tester.pumpAndSettle();

    // Onboarding is shown first.
    expect(find.text('Read it your way'), findsOneWidget);
    expect(find.text('Read the sample'), findsNothing);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Now on the library.
    expect(find.text('Open a document'), findsOneWidget);
  });
}
