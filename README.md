# Dyslexic Reader

A mobile app that helps people with **dyslexia** read more easily. Open a PDF, Word
(.docx) or plain-text file and the app re-renders it in a personalized, evidence-based reading
surface: adjustable letter/word/line **spacing**, legible **fonts**, low-glare
**themes**, a **reading ruler**, and **read-aloud with synchronized word
highlighting** — in **multiple languages**.

**Android-first, built with Flutter.** On-device by default (free, offline,
private); optional cloud upgrades later.

> Why these features and not the "famous" ones? Because the evidence says so.
> Special dyslexia fonts, "Bionic Reading", and colour-overlay therapy have weak
> or no evidence; **spacing, read-aloud-with-highlighting, and reading rulers**
> have strong evidence. We lead with what works and offer the rest as opt-in
> personalization. Full writeup in [`docs/RESEARCH.md`](docs/RESEARCH.md).

## Documentation

| Doc | What's in it |
|---|---|
| [`docs/RESEARCH.md`](docs/RESEARCH.md) | Evidence base, competitive teardown (Speechify, Immersive Reader, open-source refs), and the technical building blocks — with sources. |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | The technical blueprint: Flutter + native bridges, the document pipeline, project structure, platform channels, persistence, deployment. |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Phased build plan: shipped v1.0 scope vs post-1.0 backlog. |
| [`docs/PUBLISHING.md`](docs/PUBLISHING.md) | Zero-to-published Google Play guide: account, signing, `.aab`, hosting the policy, closed-testing gate, pre-launch checklist. |
| [`docs/STORE_LISTING.md`](docs/STORE_LISTING.md) | Copy-paste Play listing: title, descriptions, Data Safety answers, content rating, assets. |
| [`docs/PRIVACY_POLICY.md`](docs/PRIVACY_POLICY.md) | The privacy policy (host this URL and link it in Play Console; also shown in-app). |
| [`docs/PDF_PARSING.md`](docs/PDF_PARSING.md) | PDF text-extraction implementation notes (backs ADR-0001). |
| [`docs/adr/`](docs/adr/) | Decision records (append-only); ledger with dates and status: [`docs/adr/README.md`](docs/adr/README.md). |
| [`STATUS.md`](STATUS.md) | Current state, open gates, verification record (single source of truth). |
| [`WORKLOG.md`](WORKLOG.md) | Dated history. |
| [`AGENTS.md`](AGENTS.md) | Operating contract for agents (commands, safety, worktree rules). |
| [`docs/agent-map.md`](docs/agent-map.md) | Entry points, task routes, do-not-load list. |
| [`docs/agent-testing.md`](docs/agent-testing.md) | Gate commands with expected output, known-red tests. |

## Features (v1.0)

Import **PDF / Word (.docx) / text** (and paste), reflow into an adjustable surface
(spacing/fonts/themes), on-device **OCR** for scanned PDFs, **read-aloud** with
synced highlighting + voice/speed/pitch controls, a draggable **reading ruler**
(4 styles), a scroll-linked reading guide, pagination or continuous scroll,
bookmarks, notes, and a document outline. Manual **highlights** (v1: one named tint,
persisted in the library index — ADR-0003; colours are post-1.0) and an
**adaptive layout**: bottom navigation on phones, side rail on tablets, and a
master-detail library at ≥ 1024 dp. First-run **onboarding**, an
**About + open-source licenses** screen, a custom **adaptive launcher icon**,
and a **TalkBack** pass are in. CI builds a signed **APK + App Bundle (.aab)**.

Current state, open gates and the publishing checklist: [`STATUS.md`](STATUS.md) and
[`docs/PUBLISHING.md`](docs/PUBLISHING.md).

## Project layout

```
lib/
  app/        MaterialApp, adaptive shell (app_shell.dart), responsive breakpoints, theme tokens
  core/       atomic file writer (storage/), platform channels (platform/: pdf_text, incoming_file)
  domain/     models, tokenizer/paginator/reflow, document structure (pure Dart, unit-tested)
  data/       prefs persistence (Riverpod), OCR service
  features/   library, reader, settings, onboarding screens
android/      Flutter Android host + native Kotlin bridges
assets/fonts/ bundled OFL fonts (OpenDyslexic, Atkinson Hyperlegible, Lexend)
assets/branding/ in-app icon; tool/generate_icons.py regenerates the icon set
distribution/whatsnew  Play release notes
docs/         research, architecture, roadmap, publishing/store/privacy, ADRs, agent guides
.github/      build.yml    analyze + test + signed APK/.aab on push/tag
              debug-apk.yml rolling debug-latest release on push to main
              release.yml  publish the .aab to Google Play on merge to `release`
```

## Develop

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable).

```bash
flutter pub get
flutter analyze
flutter test
flutter run            # on a connected Android device/emulator
flutter build apk --release
```

## Releasing a signed APK

CI (`.github/workflows/build.yml`) runs analyze + test on pushes to `main`/`claude/**`, `v*` tags
and PRs, and signs the release APK/.aab with the upload keystore injected from repository secrets
when present, otherwise it falls back to debug signing so the pipeline stays green.

Keystore generation, the secret names, and the local `android/key.properties` option live in
[`docs/PUBLISHING.md`](docs/PUBLISHING.md) Step 2.

`android/key.properties` and `*.jks` are git-ignored — never commit them.

## Licenses

App code is this project's own. Bundled fonts are under the **SIL Open Font
License**; license texts are in `assets/fonts/*-OFL.txt`.
