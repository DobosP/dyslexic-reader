# Agent Instructions — dyslexic-reader

## Project summary
- Purpose: Android-first Flutter app for dyslexic readers — opens PDF / Word (.docx) / text and re-renders it in an
  adjustable, evidence-based reading surface (spacing, fonts, themes, reading ruler, read-aloud with synced word
  highlighting). v1.0 launch candidate; current gates in `STATUS.md`.
- Main runtime: Flutter/Dart (stable; on this box `$HOME/flutter/bin`), Android host in `android/`. No fleet consumers.
- Status source: `STATUS.md`. Invariant: library/index persistence stays atomic and recoverable so user libraries are
  never silently lost (`lib/core/storage/atomic_file_writer.dart`, `lib/features/library/library_index_store.dart`).

## Fleet context
- Role: standalone product — on-device Flutter reading aid. Canonical role/status/next: vault note `dobo-brain/paul-brain/projects/dyslexic-reader.md`
  (fleet view: vault `projects/index.md` + `NOW.md`; agent-ops ADR-0032). Upstream: none · Downstream: none.
- Fleet map + parallel-agent protocol: `~/work/AGENTS.md` (agent-ops ADR-0025/0026). Global session, git,
  scratch and secrets rules: `~/.claude/CLAUDE.md` (agent-ops ADR-0027/0028/0037/0063/0074/0077) — cited here, not restated.
- Delegation: roles and rungs per the `agent-routing` skill (the ladder in `fleet-tiers.sh`); Codex is opt-in (agent-ops ADR-0065).

## Parallel work (mandatory)
- This shared checkout stays on `main`, clean — clean includes untracked (agent-ops ADR-0063): `git status --porcelain`
  is empty when you finish; a stray file blocks the next task-worktree/Ctrl-N session here. A stray file you
  did not write gets reported, not deleted.
- One task = one branch (`<type>/<slug>`) = one worktree `~/work/_worktrees/dyslexic-reader/<slug>`, never under `/tmp`:
  `python3 ~/work/agent-ops/scripts/create_task_worktree.py --repo ~/work/dyslexic-reader --branch <type>/<slug> --task "..." --write`
  Scratch and one-off scripts: `~/work/_temp/<slug>/`, run against this repo by path (agent-ops ADR-0028).
- Workers never push. The orchestrating session lands green work on `main` (agent-ops ADR-0014) and finishes the landing
  in the same session (agent-ops ADR-0037): delete the verified-merged branch (local + origin), its worktree, `_temp/<slug>/`.
  Unmerged work is deleted only per item, human-confirmed. A branch reaches origin only on land or by
  `ops publish dyslexic-reader <branch>` — `ops sync` never creates a remote ref (agent-ops ADR-0077).

## Read first
1. `STATUS.md` — current state, open gates, verification record.
2. `docs/agent-map.md` (entry points, task routes, do-not-load) and `docs/agent-testing.md` (gate commands + expected output).
3. `README.md` §Documentation for deep docs; then only the feature file and matching test named in the task.

## Commands
| Scope | Command |
|---|---|
| Flutter on PATH | `export PATH="$HOME/flutter/bin:$PATH"` — prepend before declaring tests unavailable |
| Install | `flutter pub get` |
| Targeted test (persistence) | `flutter test test/library_index_store_test.dart` |
| Full gate | `flutter analyze && flutter test` |
| Whitespace | `git diff --check` |
| Release build | `flutter build apk --release` · `flutter build appbundle --release` (CI: `.github/workflows/build.yml`) |

Expected outputs and known-red tests: `docs/agent-testing.md`.

## Safety
- Secrets: names only — `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`,
  `PLAY_SERVICE_ACCOUNT_JSON` (registry `agent-ops/secrets/secrets.manifest.yaml`, agent-ops ADR-0027). Never read or print
  `android/key.properties`, `*.jks`/keystores, env files, or service-account files.
- Never weaken persistence/recovery guarantees for library data. A persistence change ships with a test in
  `test/library_index_store_test.dart` or `test/atomic_file_writer_test.dart`; its brief states exact user-data
  recovery acceptance criteria. Do not claim full app validation from one targeted persistence test.
- Land only on a green `flutter analyze && flutter test`; a red suite is never landed. Summarize test output; never
  paste large Flutter logs. One feature or persistence fix per branch/worktree.
- Do not load `build/**`, generated platform artifacts, or signing configs unless the task requires them.

## Docs discipline (mandatory)
- `STATUS.md` is this repo's single source of current truth. On conflict: `STATUS.md` > newest-dated ADR in
  `docs/adr/` > everything else. An undated doc is history, not instructions.
- Definition of done for any change of behavior, architecture, status, or decision — same commit: update
  `STATUS.md` (facts + `Last verified: YYYY-MM-DD`); a decision made or reverted gets `docs/adr/NNNN-<slug>.md`
  (claim the number in `docs/adr/README.md`; flip the superseded ADR's `Status:`).
- ADRs are append-only. No decision language ("we use X", "default is") in READMEs/guides — link the ADR.
- Continuation lives in the tab handoff and the vault task note (agent-ops ADR-0078), never a new dated handoff. Dated
  records open with `Valid until: <event> — then treat as history.`
- Budgets: this file ≤ 80 lines, `CLAUDE.md` ≤ 12 non-blank, `STATUS.md` ≤ 120, `docs/agent-map.md` ≤ 60,
  `docs/agent-testing.md` ≤ 80. History overflows to `WORKLOG.md`. Convention: `agent-ops/docs/29-doc-governance.md`.
