import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/reading_theme.dart';
import '../../data/prefs/prefs_repository.dart';
import '../settings/reading_prefs_controller.dart';

const _kOnboardingKey = 'onboarding_seen_v1';

/// Whether the first-run onboarding has been completed.
final onboardingSeenProvider = Provider<bool>(
  (ref) => ref.watch(sharedPreferencesProvider).getBool(_kOnboardingKey) ?? false,
);

/// Mark onboarding complete and let the app gate (app.dart) swap to the library.
Future<void> markOnboardingSeen(WidgetRef ref) async {
  await ref.read(sharedPreferencesProvider).setBool(_kOnboardingKey, true);
  ref.invalidate(onboardingSeenProvider);
}

class _Page {
  const _Page({required this.icon, required this.title, required this.body, this.bullets});
  final IconData icon;
  final String title;
  final String body;
  final List<String>? bullets;
}

const _pages = <_Page>[
  _Page(
    icon: Icons.menu_book_outlined,
    title: 'Read it your way',
    body: 'Open a PDF, Word document, or text file and Dyslexic Reader '
        're-renders it in a calm, comfortable reading surface you control.',
  ),
  _Page(
    icon: Icons.tune,
    title: 'Made for easier reading',
    body: 'Adjust everything to suit you — these have the strongest evidence '
        'for helping dyslexic readers:',
    bullets: [
      'Generous letter, word, and line spacing',
      'Legible fonts and gentle, low-glare colours',
      'A reading ruler that keeps your place',
      'Read-aloud with the words highlighted as they’re spoken',
    ],
  ),
  _Page(
    icon: Icons.lock_outline,
    title: 'Private and free',
    body: 'Everything happens on your device. No ads, no accounts, no tracking — '
        'your documents never leave your phone.',
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= _pages.length - 1) {
      markOnboardingSeen(ref);
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteFor(ref.watch(readingPrefsProvider).themeId);
    final theme = Theme.of(context);
    final isLast = _index == _pages.length - 1;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => markOnboardingSeen(ref),
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _PageView(page: _pages[i], palette: palette),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? palette.accent
                          : palette.onBackground.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: palette.background,
                    minimumSize: const Size.fromHeight(52),
                    textStyle: theme.textTheme.titleMedium,
                  ),
                  onPressed: _next,
                  child: Text(isLast ? 'Get started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({required this.page, required this.palette});

  final _Page page;
  final ReadingPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(page.icon, size: 72, color: palette.accent),
          const SizedBox(height: 28),
          Text(
            page.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: palette.onBackground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            page.body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: palette.onBackground,
              height: 1.5,
            ),
          ),
          if (page.bullets != null) ...[
            const SizedBox(height: 16),
            for (final b in page.bullets!)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline, size: 22, color: palette.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        b,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: palette.onBackground,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
