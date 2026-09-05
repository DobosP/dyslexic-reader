# Worklog — dyslexic-reader

Append-only, dated, newest first. Current truth lives in [`STATUS.md`](STATUS.md); this file is the overflow for
dated records.

## 2026-09-05 — docs refresh (fleet doc convention v2)

- `AGENTS.md` / `CLAUDE.md` re-stamped to the convention stanzas (`agent-ops/docs/29-doc-governance.md` §3);
  `STATUS.md` gains open gates + a verification record and its dated narrative moved here; `README.md` owns the
  feature inventory and a one-hop doc index; `docs/ROADMAP.md` and `docs/ARCHITECTURE.md` status copies replaced
  by pointers to `STATUS.md`.
- `docs/ARCHITECTURE.md` §4 blueprint tree (named `router.dart`, `data/db/` drift, `features/tts/`, `core/utils/`,
  `core/result.dart` — none of which exist) replaced by a description of the real layout.
- `docs/ARCHITECTURE.md` §2/§3/§5.2/§8 corrected to the shipped stack: no go_router (Navigator + `IndexedStack`
  shell), no drift (atomic JSON library index), no language-ID, TTS via `flutter_tts` (only `pdf_text` and
  `incoming` are hand-written channels). `docs/adr/README.md` ledger created; commit SHAs removed from living
  docs (`STATUS.md`, `docs/ROADMAP.md`, `docs/ARCHITECTURE.md`).
- Gate re-run on Flutter 3.44.2 stable: `flutter analyze` clean; `flutter test` 84 passed / 3 failed. The three
  widget tests come from the 2026-07-07 commit a56d8d7 and had never been run — recorded as an open gate in
  `STATUS.md`.

## 2026-07-07 — highlights v1 recovered; adaptive UI verified

Adaptive/responsive UI merged to `main` and verified on the Linux Flutter host: `flutter analyze` clean, full
`flutter test` green (84). Current decision record: ADR-0003 (supersedes ADR-0002). *(This gate predates the three
widget tests added the same day in a56d8d7, which `STATUS.md` then recorded as "authored but not run here".)*

- **Stage 1** — foundations + adaptive nav. `lib/app/responsive/breakpoints.dart` (WindowSize + ResponsiveCenter),
  `lib/app/theme/app_tokens.dart` (AppTokens ThemeExtension in `buildAppTheme`), `lib/app/app_shell.dart` (bottom
  `NavigationBar` on phones ↔ side `NavigationRail` on tablet/landscape, Library + Settings, `IndexedStack`,
  back-to-Library `PopScope`). `app.dart` home → `AppShell`. Library/Settings centered at readable max-width on wide
  screens; Library's silent load-error branch now shows a retry panel.
- **Stage 2** — tablet layout + dedup. Library is **master-detail** on expanded (≥ 1024 dp) screens: list pane
  (380 dp) + reading pane that embeds `ReaderScreen` for the selected entry (`_selected`/`_selectedDoc`,
  `FutureBuilder<ReadingDocument>`, keyed by entry id); phone/medium path unchanged (still pushes full-screen).
  Shared `ThemeChoiceChips`/`FontChoiceChips` (`lib/features/settings/widgets/reading_pref_controls.dart`) now used
  by both Settings and the reader's Text-&-display sheet (kills the duplicated chips the recon flagged). Deleting
  the selected entry on wide layouts now clears the detail pane instead of leaving stale reader content; the unused
  `readerSideGutter` token was removed.
- **Still deferred** (needs runtime eyeballing): reader TTS/app-bar chrome adaptivity, `reader_screen.dart`
  god-widget split, full slider-control dedup.
- Manual persisted text highlights recovered: saved highlight ranges round-trip in the library index, can be added
  from long-press / current reader position actions, are listed/deletable, render inline in the reader, and have
  ReaderScreen widget coverage. Highlighting v1 intentionally uses one named tint; colored highlights remain
  ROADMAP v2.

## 2026-07-06 — branch consolidation

- Adaptive/responsive UI branch merged to `main` during the 2026-07-06 consolidation; ADR-0002 added 2026-07-07
  (5d236a7) and superseded by ADR-0003 the same day.
