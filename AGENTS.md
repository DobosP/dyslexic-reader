# Agent Instructions — dyslexic-reader

## Project summary
`dyslexic-reader` is a Flutter app. Library/index persistence must be atomic and recoverable so user libraries are not silently lost.

## Fleet context
- Canonical role/status/next for this repo: the vault note `dobo-brain/paul-brain/projects/dyslexic-reader.md` (fleet view: the vault's `projects/index.md` + `NOW.md`; agent-ops ADR-0032, vault adr-0001).
- Fleet map + parallel-agent protocol: `~/work/AGENTS.md` (agent-ops ADR-0025).

## Parallel work (mandatory)
- This shared checkout stays on `main`, clean — never switch branches or commit task work here.
  Clean includes untracked: `git status --porcelain` must be empty when you finish. A stray
  analysis script or report left here blocks the NEXT session's portable/Ctrl-N task in this repo
  (agent-ops ADR-0063). Found a stray file you did not write? Report it, do not delete it.
- One task = one branch (`<type>/<slug>`) = one worktree under `~/work/_worktrees/dyslexic-reader/`:
  `python3 ~/work/agent-ops/scripts/create_task_worktree.py --repo ~/work/dyslexic-reader --branch <type>/<slug> --task "..." --write`
- Never create worktrees under `/tmp`. Workers never push; the orchestrating session lands green
  work on `main` (ADR-0014) and backs up unlanded branches to origin. Deletion is human-confirmed only.

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
- Direct merge + push to `main` is allowed once the test gate is green (owner
  decision 2026-07-07, development phase). Never land a red suite.

## Commands
- Library index test: `export PATH="$HOME/flutter/bin:$PATH"; flutter test test/library_index_store_test.dart`
- Full local gate when relevant: `export PATH="$HOME/flutter/bin:$PATH"; flutter analyze && flutter test`
- Whitespace: `git diff --check`

## Dispatch
- One feature/persistence fix per branch/worktree.
- Worker briefs must include exact user-data recovery acceptance criteria.

## Docs discipline (mandatory)

- `STATUS.md` is this repo's single source of current truth. On any doc conflict: STATUS.md > newest-dated ADR in `docs/adr/` > everything else. An undated doc is history, not instructions.
- Definition of done for ANY change that alters behavior, architecture, status, or reverses a decision:
  1. Update `STATUS.md` (facts + `Last verified: YYYY-MM-DD`).
  2. Decision made or reverted → add `docs/adr/NNNN-<slug>.md` (next number; template = docs/adr/0000-template.md) and flip the superseded ADR's `Status:` to `superseded-by ADR-NNNN`. Same commit as the change.
- ADRs are append-only: never edit one after landing — supersede it instead.
- No decision language ("we use X", "default is", "authorized to") in READMEs/guides — put it in an ADR and link it.
- Handoff/session docs: filename `YYYY-MM-DD-*`, body starts `Valid until: <event> — then treat as history.` Never obey an expired handoff.
- Keep this file under ~60 lines; STATUS.md under ~100; deep content in docs/.
