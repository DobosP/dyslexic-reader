# Agent Testing Guide — dyslexic-reader

## Environment
- Runtime: Flutter/Dart.
- Flutter path on this box: `$HOME/flutter/bin`.

## Commands
| Scope | Command | Expected success |
|---|---|---|
| Library index persistence | `export PATH="$HOME/flutter/bin:$PATH"; flutter test test/library_index_store_test.dart` | `14 tests passed` on current setup |
| Analyze + tests | `export PATH="$HOME/flutter/bin:$PATH"; flutter analyze && flutter test` | clean analyze; tests pass |
| Whitespace | `git diff --check` | no output |

## Before commit
1. Run `git diff --check`.
2. Run targeted Flutter tests for changed feature files.
3. Run `flutter analyze` for broader feature/platform changes.
4. Record exact command output in worker result files.

## Known blockers
- If Flutter is missing from PATH, prepend `$HOME/flutter/bin` before declaring tests unavailable.
- Do not read/print signing credentials, keystores, or env files.
