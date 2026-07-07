# ADR-0002 — Adaptive navigation shell + tablet master-detail library

- **Status:** accepted (2026-07-07; retroactive — the code merged to main on
  2026-07-06 during the fleet branch consolidation, gate verified 2026-07-07)
- **Context:** the app was phone-only: `app.dart` pushed full-screen routes and
  the library and reader never used tablet width. The adaptive-UI work
  (`feat/adaptive-responsive-ui`, static-reviewed on a Windows box, later
  merged) restructures navigation and layout per window size.

## Decision

1. **One navigation shell** — `lib/app/app_shell.dart`. Home is `AppShell`, an
   `IndexedStack` over Library + Settings with a bottom `NavigationBar` on
   phones and a side `NavigationRail` on tablet/landscape (`WindowSize` from
   `lib/app/responsive/breakpoints.dart`). Back from a tab returns to Library
   (`PopScope`) instead of exiting.
2. **Tablet master-detail library** — at expanded width (≥1024 dp)
   `library_screen.dart` renders a 380 dp list pane plus a reading pane that
   embeds `ReaderScreen` for the selected entry, keyed by entry id. Phone and
   medium widths keep the full-screen push unchanged.
3. **Design tokens over ad-hoc constants** — `AppTokens` (`ThemeExtension`) in
   `lib/app/theme/app_tokens.dart`, applied via `buildAppTheme`; shared reading
   preference controls live in
   `lib/features/settings/widgets/reading_pref_controls.dart` and are used by
   both Settings and the reader's text-and-display sheet.

## Consequences

- New screens must render inside `AppShell` tabs or as routes pushed above it;
  don't add parallel scaffolds with their own navigation bars.
- Wide-layout behavior must be exercised when touching library/reader flows —
  a known gap: the detail pane can keep showing a deleted entry until a new
  selection (`library_screen.dart`, `_selected`; tracked in STATUS deferred
  list).
- Deferred (runtime-eyeballing needed, see STATUS): reader TTS/app-bar chrome
  adaptivity, `reader_screen.dart` god-widget split, full slider-control dedup,
  the unused `readerSideGutter` token.
