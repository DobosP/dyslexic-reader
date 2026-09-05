# Status — dyslexic-reader

Last verified: 2026-09-05 (Linux Flutter host, Flutter 3.44.2 stable: analyze clean; full suite 84 passed / 3 failed — see Open gates)

Single source of current truth for this repo. On conflict: this file > newest-dated ADR in `docs/adr/` > everything else.

## Current state

- **v1.0 launch candidate**, `pubspec.yaml` `version: 1.0.0+1`. Feature inventory: [`README.md`](README.md) §Features.
  Remaining before release: the red-suite gate below (code), then the publishing process gated by
  [`docs/PUBLISHING.md`](docs/PUBLISHING.md): Play account, hosted privacy-policy URL, screenshots, closed test.
- Manual text highlights v1 (one named tint) persist in the library index, are addable from long-press / current
  reading position, listed, deletable, and rendered inline. Colored highlights are ROADMAP v2.
- Adaptive UI merged: bottom `NavigationBar` on phones / `NavigationRail` on tablet-landscape
  (`lib/app/app_shell.dart`, `lib/app/responsive/breakpoints.dart`); Library master-detail at ≥ 1024 dp
  (380 dp list pane + embedded `ReaderScreen`); shared `ThemeChoiceChips`/`FontChoiceChips` in
  `lib/features/settings/widgets/reading_pref_controls.dart`. Decision: ADR-0003 (supersedes ADR-0002).
  Deferred, needs runtime eyeballing: reader TTS/app-bar chrome adaptivity, `reader_screen.dart` god-widget split,
  slider-control dedup.
- Post-1.0 backlog: unchecked items in [`docs/ROADMAP.md`](docs/ROADMAP.md) (lang-ID, RTL, iOS, localization,
  AI summaries).
- Decisions: ledger [`docs/adr/README.md`](docs/adr/README.md); newest ADR-0003 (reader highlight UI +
  master-detail delete, supersedes ADR-0002); ADR-0001 PDF parsing = PdfBox-Android subclassed stripper.

## Open gates

- **RED SUITE.** Three widget tests (two in `test/reader_highlight_flow_test.dart`, one in
  `test/library_master_detail_test.dart`) fail on Flutter 3.44.2 and have never run green: they were authored in
  the 2026-07-07 highlight/master-detail change on a host without Flutter (`WORKLOG.md` 2026-07-07). Exact test
  names, failing finder and line: [`docs/agent-testing.md`](docs/agent-testing.md) §Known red. The full gate must
  be green before any code lands (agent-ops ADR-0014); whether the tests or the UI are wrong is an open code task, not
  decided here.
- Publishing process: `docs/PUBLISHING.md` Steps 1 (Play org account), 4 (hosted privacy-policy URL),
  5 (listing + screenshots), 7 (closed test).
- Play signing/upload secrets set as GitHub repository secrets before the first push to `release`
  (names in `AGENTS.md` §Safety; `.github/workflows/release.yml`).

## Next actions

1. Green the three red widget tests — own branch, code task (blocks every other landing).
2. Run the publishing process per `docs/PUBLISHING.md`.
3. Deferred adaptive-UI items above, post-1.0.

## Verification record

**2026-09-05** — Linux host, Flutter 3.44.2 stable / Dart 3.12.2, `export PATH="$HOME/flutter/bin:$PATH"`:

| Command | Result |
|---|---|
| `flutter pub get` | `Got dependencies!` |
| `flutter analyze` | `No issues found!` |
| `flutter test test/library_index_store_test.dart` | `+15: All tests passed!` |
| `flutter test test/atomic_file_writer_test.dart` | `+3: All tests passed!` |
| `flutter test` | `+84 -3: Some tests failed.` — exactly the 3 known-red tests in `docs/agent-testing.md` |
| `flutter build apk --release` | not run — no Android SDK on this host; CI `.github/workflows/build.yml` is the reference build |
| `git diff --check` | no output |
| `python3 ~/work/agent-ops/scripts/check_docs.py .` | `files=13 dead_links=0 stale_terms=0 retired_verbs=0 orphans=0` |
| `check_project_contexts.py --repo <worktree>` | row `dyslexic-reader` ok — AGENTS/CLAUDE `68/3` lines, thin pointer yes, `STATUS.md` (66) |

Earlier records: [`WORKLOG.md`](WORKLOG.md).

## Doc map

[`README.md`](README.md) §Documentation indexes every doc in one hop; agent entry points
[`docs/agent-map.md`](docs/agent-map.md); gate commands and expected output
[`docs/agent-testing.md`](docs/agent-testing.md); dated history [`WORKLOG.md`](WORKLOG.md).
