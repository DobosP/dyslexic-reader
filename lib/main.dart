import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'data/prefs/prefs_repository.dart';

/// Register the bundled fonts' SIL Open Font License texts so they appear on
/// the in-app open-source licenses page (Settings → About → licenses).
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    const sources = {
      'OpenDyslexic': 'assets/fonts/OpenDyslexic-OFL.txt',
      'Atkinson Hyperlegible': 'assets/fonts/AtkinsonHyperlegible-OFL.txt',
      'Lexend': 'assets/fonts/Lexend-OFL.txt',
    };
    for (final entry in sources.entries) {
      final text = await rootBundle.loadString(entry.value);
      yield LicenseEntryWithLineBreaks([entry.key], text);
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const DyslexicReaderApp(),
    ),
  );
}
