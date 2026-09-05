# Agent Map — dyslexic-reader

## What this repo owns
- Flutter reader app UX and local library/index persistence.
- User-facing library data recovery behavior.

## Entry points
| Area | Path | Notes |
|---|---|---|
| Flutter source | `lib/` | Main app/features. |
| Library feature | `lib/features/library/` | Library controller/index store. |
| Atomic persistence | `lib/core/storage/atomic_file_writer.dart` | temp/primary/backup rename protocol. |
| Platform channels | `lib/core/platform/` | `pdf_text_channel.dart`, `incoming_file_channel.dart` (Kotlin side under `android/app/src/main/kotlin/`). |
| Adaptive shell | `lib/app/app_shell.dart`, `lib/app/responsive/breakpoints.dart` | phone bottom nav ↔ tablet rail; master-detail ≥ 1024 dp. |
| Reader | `lib/features/reader/reader_screen.dart` | Large widget; TTS, ruler, highlights, search live here. |
| Tests | `test/` | Flutter test suite. |
| Gate commands | `docs/agent-testing.md` | Expected output + known-red tests. |
| Status | `STATUS.md` | Current truth, open gates, verification record. |

## Common task routes
| Task type | Start here | Verify with |
|---|---|---|
| Library persistence | `lib/features/library/`, `test/library_index_store_test.dart` | targeted Flutter test |
| UI/UX change | relevant `lib/features/` files | targeted/full Flutter tests + analyze |
| Platform/build issue | platform dir + `pubspec.yaml` | platform-specific build/test |
| Release/publishing | `docs/PUBLISHING.md`, `.github/workflows/*.yml` | `flutter build appbundle --release` (CI does the signing) |
| Docs/status | `STATUS.md`, `README.md` | `git diff --check`; `python3 ~/work/agent-ops/scripts/check_docs.py .` line pasted into `STATUS.md` |

## Do not load by default
- `build/**`, `.dart_tool/`
- Generated platform artifacts
- Signing configs/keystores/env files
- Large Flutter logs
- `pubspec.lock` unless the task is dependency work

## Known pitfalls
- Local index reads can heal/write on disk; document that when changing persistence code.
- Atomic rename assumptions depend on temp/primary/backup living in the same directory.
- A full-suite failure is not necessarily yours: compare against the known-red list in `docs/agent-testing.md`
  §Known red before debugging.
