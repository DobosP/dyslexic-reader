# Status — dyslexic-reader

Last verified: 2026-07-07 (merge-audit working tree: `git diff --check` clean; Flutter/Dart unavailable in this sandbox, so widget tests were authored but not run here)

Single source of current truth for this repo. On any doc conflict:
this file > newest-dated ADR in `docs/adr/` > everything else.

## Current state

- **v1.0 launch candidate — feature-complete.** `README.md` §Status is the
  verified feature-status truth (OCR, .docx import, read-aloud with word sync,
  reading ruler, outline, onboarding, TalkBack pass all shipped in code).
- Manual persisted text highlights have been recovered: saved highlight ranges
  round-trip in the library index, can be added from long-press/current reader
  position actions, are listed/deletable, render inline in the reader, and have
  ReaderScreen widget coverage. Highlighting v1 intentionally uses one named
  tint; colored highlights remain ROADMAP v2.
- Remaining work before release is **process, not code**, gated by
  [`docs/PUBLISHING.md`](docs/PUBLISHING.md): Play account, hosted
  privacy-policy URL, screenshots, closed test.
- Post-1.0 backlog: [`docs/ROADMAP.md`](docs/ROADMAP.md) (unchecked items —
  lang-ID, RTL, iOS, localization, AI summaries are genuinely not in v1.0).
- Decisions: [`docs/adr/`](docs/adr/) (ADR-0001: PDF parsing = PdfBox-Android
  subclassed stripper).

## Adaptive/responsive UI (MERGED to main; gate green 2026-07-07)

Landed during the 2026-07-06 branch consolidation and verified on the Linux
Flutter host on 2026-07-07: `flutter analyze` clean, full `flutter test` green
(84). Current decision record: ADR-0003 (supersedes ADR-0002).

- **Stage 1** — foundations + adaptive nav. `lib/app/responsive/breakpoints.dart`
  (WindowSize + ResponsiveCenter), `lib/app/theme/app_tokens.dart` (AppTokens
  ThemeExtension in `buildAppTheme`), `lib/app/app_shell.dart` (bottom
  `NavigationBar` on phones ↔ side `NavigationRail` on tablet/landscape, Library
  + Settings, `IndexedStack`, back-to-Library `PopScope`). `app.dart` home →
  `AppShell`. Library/Settings centered at readable max-width on wide screens;
  Library's silent load-error branch now shows a retry panel.
- **Stage 2** — tablet layout + dedup. Library is now **master-detail** on
  expanded (≥1024 dp) screens: list pane (380 dp) + reading pane that embeds
  `ReaderScreen` for the selected entry (`_selected`/`_selectedDoc`,
  `FutureBuilder<ReadingDocument>`, keyed by entry id); phone/medium path
  unchanged (still pushes full-screen). Shared `ThemeChoiceChips`/`FontChoiceChips`
  (`lib/features/settings/widgets/reading_pref_controls.dart`) now used by both
  Settings and the reader's Text-&-display sheet (kills the duplicated chips the
  recon flagged). Deleting the selected entry on wide layouts now clears the
  detail pane instead of leaving stale reader content; the unused
  `readerSideGutter` token was removed.
- **Still deferred** (needs runtime eyeballing): reader TTS/app-bar chrome
  adaptivity, `reader_screen.dart` god-widget split, full slider-control dedup.

## Role in the fleet

Standalone Flutter reader app with local user-library persistence.

## Current operational focus

- Preserve user library data across torn/corrupt index writes.
- Keep index-store recovery behavior tested.
- Treat signing configs, keystores, and env files as secret-sensitive.

## Standard verification

```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter test test/library_index_store_test.dart
git diff --check
```

## Agent notes

- Do not claim full app validation from one targeted persistence test.
- Never read or print secret values.
