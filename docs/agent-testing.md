# Agent Testing Guide — dyslexic-reader

Last verified: 2026-09-05 (Flutter 3.44.2 stable, Linux host)

## Environment
- Runtime: Flutter/Dart stable. Flutter on this box: `$HOME/flutter/bin` —
  `export PATH="$HOME/flutter/bin:$PATH"` first; only after that may a session say tests are unavailable.
- `flutter pub get` once per fresh worktree.

## Gate commands
| Scope | Command | Expected |
|---|---|---|
| Analyze | `flutter analyze` | `No issues found!` |
| Library index persistence | `flutter test test/library_index_store_test.dart` | `+15: All tests passed!` |
| Atomic writer | `flutter test test/atomic_file_writer_test.dart` | `+3: All tests passed!` |
| Full suite | `flutter test` | 87 tests. As of Last verified: `+84 -3: Some tests failed.` — exactly the three in §Known red. Green = `+87: All tests passed!` |
| Whitespace | `git diff --check` | no output |

## Known red / blocked
- Red since 2026-07-07, never run green (authored on a host without Flutter):
  `test/reader_highlight_flow_test.dart` — "long-press text action saves a highlight range",
  "current-position highlight repaints, lists, and deletes";
  `test/library_master_detail_test.dart` — "wide library clears the detail pane when selected entry is removed"
  (finder `text("Remove")` finds 0 widgets, line 81).
  A change that touches these areas must green them; any other change must not add failures beyond these three.
- Android build/run needs a device or emulator; CI (`.github/workflows/build.yml`) is the reference build.

## Before commit
1. `git diff --check`.
2. Targeted tests for changed feature files, then `flutter analyze`.
3. Full `flutter test`; compare failures against the known-red list above.
4. Record the command + result line in the `STATUS.md` verification record, same commit — not in a result file.
5. Never read or print signing credentials, keystores, or env files.
