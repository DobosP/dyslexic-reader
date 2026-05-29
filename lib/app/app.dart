import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/library/library_screen.dart';
import '../features/settings/reading_prefs_controller.dart';
import 'theme/reading_theme.dart';

class DyslexicReaderApp extends ConsumerWidget {
  const DyslexicReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeId = ref.watch(readingPrefsProvider.select((p) => p.themeId));
    return MaterialApp(
      title: 'Dyslexic Reader',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(themeId),
      home: const LibraryScreen(),
    );
  }
}
