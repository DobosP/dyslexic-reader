import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/reading_prefs.dart';

/// Provides the [SharedPreferences] instance. Overridden at app start (and in
/// tests) with a concrete instance so the rest of the app stays synchronous.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden at app start',
  ),
);

/// Loads and saves [ReadingPrefs]. Tolerant of missing/corrupt data.
class PrefsRepository {
  PrefsRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'reading_prefs_v1';

  ReadingPrefs load() {
    final s = _prefs.getString(_key);
    if (s == null) return const ReadingPrefs();
    try {
      return ReadingPrefs.decode(s);
    } catch (_) {
      return const ReadingPrefs();
    }
  }

  Future<void> save(ReadingPrefs prefs) => _prefs.setString(_key, prefs.encode());
}

final prefsRepositoryProvider = Provider<PrefsRepository>(
  (ref) => PrefsRepository(ref.watch(sharedPreferencesProvider)),
);
