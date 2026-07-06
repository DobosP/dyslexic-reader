import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/reading_prefs_controller.dart';
import 'app_shell.dart';
import 'theme/reading_theme.dart';

class DyslexicReaderApp extends ConsumerWidget {
  const DyslexicReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeId = ref.watch(readingPrefsProvider.select((p) => p.themeId));
    final onboarded = ref.watch(onboardingSeenProvider);
    return MaterialApp(
      title: 'Dyslexic Reader',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(themeId),
      home: onboarded ? const AppShell() : const OnboardingScreen(),
    );
  }
}
