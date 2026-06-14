import 'package:dyslexic_reader/data/prefs/prefs_repository.dart';
import 'package:dyslexic_reader/domain/models/library_entry.dart';
import 'package:dyslexic_reader/domain/reflow/tokenizer.dart';
import 'package:dyslexic_reader/features/library/library_controller.dart';
import 'package:dyslexic_reader/features/reader/reader_screen.dart';
import 'package:dyslexic_reader/features/settings/tts_voice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmptyLibrary extends LibraryController {
  @override
  Future<List<LibraryEntry>> build() async => <LibraryEntry>[];
}

void main() {
  // Fake the native text-to-speech engine so read-aloud can be exercised
  // headlessly (no device, no real TTS). Records the calls the app makes.
  const channel = MethodChannel('flutter_tts');
  late List<String> ttsCalls;

  setUp(() {
    ttsCalls = [];
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      ttsCalls.add(call.method);
      switch (call.method) {
        case 'getVoices':
          return <Map<String, String>>[
            {'name': 'en-us-voice', 'locale': 'en-US'},
            {'name': 'fr-fr-voice', 'locale': 'fr-FR'},
          ];
        case 'getLanguages':
          return <String>['en-US', 'fr-FR'];
        default:
          return 1; // success for speak/stop/setRate/setVoice/setPitch/...
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<SharedPreferences> prefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  testWidgets('read-aloud starts and stops without a device', (tester) async {
    final sp = await prefs();
    final doc = Tokenizer.parse(
      'The quick brown fox jumps over the lazy dog. Reading aloud is calm.',
      title: 'Test',
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        libraryControllerProvider.overrideWith(_EmptyLibrary.new),
      ],
      child: MaterialApp(home: ReaderScreen(document: doc)),
    ));
    await tester.pumpAndSettle();

    // Start playback via the FAB.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(ttsCalls, contains('speak'));
    // The in-reader TTS bar (speed control) only shows while playing.
    expect(find.byIcon(Icons.speed), findsOneWidget);

    // Pause via the FAB again.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(ttsCalls, contains('stop'));
    expect(find.byIcon(Icons.speed), findsNothing);
  });

  testWidgets('voice picker lists the engine voices', (tester) async {
    final sp = await prefs();
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
      child: const MaterialApp(home: TtsVoiceScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Device default'), findsOneWidget);
    expect(find.text('en-us-voice'), findsOneWidget);
    expect(find.text('fr-fr-voice'), findsOneWidget);
  });
}
