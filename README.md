# Dyslexic Reader

A mobile app that helps people with **dyslexia** read more easily. Open a PDF or
plain text and the app re-renders it in a personalized, evidence-based reading
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
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Phased build plan and current status. |

## Status

**Phase 0 — foundation (current):** a working, deployable plain-text reader with
adjustable spacing/typography/themes and an optional bionic toggle, plus CI that
produces a signed APK. PDF import, read-aloud, OCR, and the reading ruler land in
later phases (see the roadmap).

## Project layout

```
lib/
  app/        MaterialApp, theme system
  domain/     models, tokenizer, reflow logic (pure Dart, unit-tested)
  data/       prefs persistence (Riverpod providers)
  features/   library, reader, settings screens
android/      Flutter Android host (native bridges added in later phases)
assets/fonts/ bundled OFL fonts (OpenDyslexic, Atkinson Hyperlegible, Lexend)
docs/         research + architecture + roadmap
.github/      CI: analyze + test + build signed APK
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

CI (`.github/workflows/build.yml`) runs analyze + test on every push and builds a
release APK, uploaded as a build artifact (and attached to a GitHub Release on
`v*` tags).

To build a **release-signed** APK (otherwise CI falls back to debug signing),
add these repository secrets:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 your-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |

Generate a keystore once with:

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`android/key.properties` and `*.jks` are git-ignored — never commit them.

## Licenses

App code is this project's own. Bundled fonts are under the **SIL Open Font
License**; license texts are in `assets/fonts/*-OFL.txt`.
