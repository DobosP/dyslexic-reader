# Agent Map — dyslexic-reader

## What this repo owns
- Flutter reader app UX and local library/index persistence.
- User-facing library data recovery behavior.

## Entry points
| Area | Path | Notes |
|---|---|---|
| Flutter source | `lib/` | Main app/features. |
| Library feature | `lib/features/library/` | Library controller/index store. |
| Tests | `test/` | Flutter test suite. |
| Status | `STATUS.md` | Durable project status for agents. |

## Read first
1. `AGENTS.md`
2. `STATUS.md`
3. `docs/agent-testing.md`
4. Relevant `lib/` feature and `test/` file

## Common task routes
| Task type | Start here | Verify with |
|---|---|---|
| Library persistence | `lib/features/library/`, `test/library_index_store_test.dart` | targeted Flutter test |
| UI/UX change | relevant `lib/features/` files | targeted/full Flutter tests + analyze |
| Platform/build issue | platform dir + `pubspec.yaml` | platform-specific build/test |
| Docs/status | `STATUS.md`, `README.md` | `git diff --check` |

## Do not load by default
- `build/**`
- Generated platform artifacts
- Signing configs/keystores/env files
- Large Flutter logs

## Known pitfalls
- Local index reads can heal/write on disk; document that when changing persistence code.
- Atomic rename assumptions depend on temp/primary/backup living in the same directory.
