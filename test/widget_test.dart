import 'package:dyslexic_reader/app/app.dart';
import 'package:dyslexic_reader/data/prefs/prefs_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots to the library screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const DyslexicReaderApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dyslexic Reader'), findsOneWidget);
    expect(find.text('Read the sample'), findsOneWidget);
  });
}
