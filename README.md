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
| [`docs/PUBLISHING.md`](docs/PUBLISHING.md) | Zero-to-published Google Play guide: account, signing, `.aab`, hosting the policy, closed-testing gate, pre-launch checklist. |
| [`docs/STORE_LISTING.md`](docs/STORE_LISTING.md) | Copy-paste Play listing: title, descriptions, Data Safety answers, content rating, assets. |
| [`docs/PRIVACY_POLICY.md`](docs/PRIVACY_POLICY.md) | The privacy policy (host this URL and link it in Play Console; also shown in-app). |

## Status

**Launch-candidate (v1.0).** A complete, deployable reader: import **PDF / Word
(.docx) / text** (and paste), reflow into an adjustable surface
(spacing/fonts/themes), on-device **OCR** for scanned PDFs, **read-aloud** with
synced highlighting + voice/speed/pitch controls, a draggable **reading ruler**
(4 styles), a scroll-linked reading guide, pagination or continuous scroll,
bookmarks, notes, and a document outline. First-run **onboarding**, an
**About + open-source licenses** screen, a custom **adaptive launcher icon**,
and a **TalkBack** pass are in. CI builds a signed **APK + App Bundle (.aab)**.

Remaining before publishing is process, not code — see
[`docs/PUBLISHING.md`](docs/PUBLISHING.md): create the Play account, host the
privacy policy, capture screenshots, and run the new-account closed test.

## Project layout

```
lib/
  app/        MaterialApp, theme system
  domain/     models, tokenizer, reflow logic (pure Dart, unit-tested)
  data/       prefs persistence (Riverpod providers)
  features/   library, reader, settings screens
android/      Flutter Android host (native bridges added in later phases)
assets/fonts/ bundled OFL fonts (OpenDyslexic, Atkinson Hyperlegible, Lexend)
assets/branding/ in-app icon; tool/generate_icons.py regenerates the icon set
docs/         research + architecture + roadmap + publishing/store/privacy
.github/      CI (build.yml): analyze + test + build signed APK and .aab
              CD (release.yml): publish the .aab to Google Play on merge to `release`
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
