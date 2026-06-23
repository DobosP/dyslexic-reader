# Agent Instructions — dyslexic-reader

## Project summary
`dyslexic-reader` is a Flutter app. Library/index persistence must be atomic and recoverable so user libraries are not silently lost.

## Read first
1. `STATUS.md` for durable status.
2. `README.md` if present.
3. `docs/agent-map.md` and `docs/agent-testing.md`.
4. Task-specific Dart source and matching tests.

## Token discipline
- Do not load generated Flutter build outputs or platform directories unless the task requires them.
- Start with the feature file and matching test named in the task.
- Summarize test output; do not paste large Flutter logs.

## Safety
- Never read or print secret values from signing configs, env files, keystores, or service files.
- Do not weaken persistence/recovery guarantees for library data.
- Do not push or merge unless Paul explicitly asks.

## Commands
- Library index test: `export PATH="$HOME/flutter/bin:$PATH"; flutter test test/library_index_store_test.dart`
- Full local gate when relevant: `export PATH="$HOME/flutter/bin:$PATH"; flutter analyze && flutter test`
- Whitespace: `git diff --check`

## Dispatch
- One feature/persistence fix per branch/worktree.
- Worker briefs must include exact user-data recovery acceptance criteria.
