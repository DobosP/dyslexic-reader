# Architecture — dyslexic‑reader

Android‑first **Flutter** app that opens PDFs and plain text and re‑renders them in a
dyslexia‑friendly reading surface (adjustable spacing/typography, themes, reading ruler,
and text‑to‑speech with synchronized word highlighting), in **multiple languages**.

This document is the technical blueprint. The evidence and competitive research behind
the choices is in [RESEARCH.md](./RESEARCH.md).

---

## 1. Guiding principles

1. **Personalization over magic.** Ship evidence‑based defaults (spacing, sans‑serif,
   off‑white, left‑aligned) and make everything adjustable. (Satisfies WCAG 1.4.12.)
2. **On‑device first.** Default pipeline (PDF parse, OCR, TTS) runs locally — free,
   offline, private. Cloud is an **optional** upgrade (hybrid), never the default path.
3. **Reflow, don't just overlay.** Extract text and re‑render in our own typographic
   surface; OCR scanned PDFs; keep an "original view" only as a fallback.
4. **Flutter for everything except the two hard native bits.** Word‑boundary TTS and
   PDF text extraction go through thin native bridges (see §5); everything else is Dart.
5. **Multilingual + RTL from day one.** Separate UI language, content language, and TTS
   voice; auto‑detect content; BiDi‑correct rendering.

---

## 2. High‑level architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         Flutter (Dart)                             │
│                                                                    │
│  Presentation        ── screens, widgets (Riverpod state)          │
│   • Library / Import   • Reader  • Settings  • TTS controls         │
│                                                                    │
│  Domain (pure Dart)  ── reading model & use‑cases                  │
│   • Document, Page, Block, Line, Word, ReadingPrefs                 │
│   • Reflow/tokenize, spacing engine, ruler, bionic(optional)       │
│                                                                    │
│  Data / services     ── repositories + adapters                    │
│   • DocumentRepository  • PrefsRepository  • LibraryDb (drift)      │
│   • PdfTextService  • OcrService  • LangIdService  • TtsService     │
└─────────────┬───────────────────────────────┬────────────────────┘
              │ MethodChannel/EventChannel     │ pub.dev plugins
              ▼                                 ▼
┌──────────────────────────────┐   ┌──────────────────────────────┐
│ Native Android (Kotlin)      │   │ Flutter plugins               │
│  • PdfTextExtractor          │   │  • google_mlkit_text_recog.   │
│    (PdfBox‑Android, Apache2) │   │    (OCR, on‑device)           │
│  • TtsEngine                 │   │  • google_mlkit_language_id   │
│    (TextToSpeech +           │   │  • pdfrx (PDFium) original    │
│     onRangeStart word sync)  │   │    page render fallback       │
└──────────────────────────────┘   │  • file_picker, share, etc.   │
                                    │  • (later) sherpa_onnx neural │
                                    │    offline TTS                │
                                    └──────────────────────────────┘
```

### Document pipeline

```
import (file_picker / share intent / paste)
   │
   ├─ PDF ──► PdfTextService.extract()  ─► has usable text layer?
   │            (native PdfBox bridge)        │ yes ─► structured text (pages/blocks/lines/words)
   │                                          │ no  ─► render page bitmap ─► OcrService (ML Kit)
   │                                                                            └─ script unsupported? ─► (later) Tesseract / cloud
   │
   └─ TXT / pasted ──► plain text
        │
        ▼
   LangIdService.detect()  ─►  content language (BCP‑47) → pick TTS voice + OCR script
        │
        ▼
   Tokenizer ─► Document model (paragraphs → sentences → words, with char offsets)
        │
        ▼
   Reading surface  ── applies ReadingPrefs (spacing, font, theme, ruler, bionic?)
        │                renders reflowed RichText in a virtualized list
        ▼
   TtsService.speak(document, fromWord)  ── streams onRangeStart → highlight current word/sentence
```

---

## 3. Technology stack

| Concern | Choice | License | Why |
|---|---|---|---|
| Framework / UI | **Flutter (stable) + Material 3** | BSD | Chosen by product owner; one codebase, iOS later. |
| Language | **Dart**; **Kotlin** for native bridges | — | — |
| State management | **Riverpod 2** (`flutter_riverpod`) | MIT | Compile‑safe, testable, no `BuildContext` coupling. |
| Routing | **go_router** | BSD | Declarative, deep‑link friendly. |
| Structured persistence | **drift** (SQLite) | MIT | Library, bookmarks, reading progress. Typed, migratable. |
| Simple settings | **shared_preferences** | BSD | ReadingPrefs key‑values. |
| PDF **text** extraction | **Native bridge → PdfBox‑Android** | Apache‑2.0 | Only reliable text+positions on Android; commercial‑safe. |
| PDF **page render** (original view) | **Android `PdfRenderer`** (built-in) via native bridge | AOSP | No extra dep; renders scanned/layout-heavy pages and is the OCR raster source. |
| OCR | **google_mlkit_text_recognition** | Apache‑2.0 | On‑device, 5 scripts; Tesseract later for more. |
| Language detection | **google_mlkit_language_id** | Apache‑2.0 | On‑device, 100+ languages → voice/script selection. |
| TTS (word‑sync) | **Native bridge → Android `TextToSpeech`** (`onRangeStart`) | first‑party | Only reliable word‑boundary highlighting. |
| TTS (offline neural, later) | **sherpa_onnx** (Piper) | Apache‑2.0 | Privacy/quality upgrade; per‑language model. |
| Fonts | **OpenDyslexic** (opt‑in), **Lexend**, system sans‑serif | OFL | Spacing matters more than font; offer choice. |
| File import | **file_selector** (official) + native open‑with/share intents | BSD | Open/paste/share PDFs & text. |
| Lint | **flutter_lints** / `analysis_options.yaml` | BSD | — |

> **Licensing guardrail:** everything above is **Apache‑2.0 / BSD / MIT / OFL / first‑party**.
> We deliberately avoid **iText** and **MuPDF** (AGPL → would force open‑sourcing the whole app).

---

## 4. Project structure (feature‑first)

```
dyslexic-reader/
├─ lib/
│  ├─ main.dart                      # bootstrap, ProviderScope, theme, router
│  ├─ app/
│  │  ├─ app.dart                    # MaterialApp.router
│  │  ├─ router.dart                 # go_router routes
│  │  └─ theme/                      # dyslexia themes (cream/sepia/dark/high-contrast)
│  ├─ core/
│  │  ├─ result.dart                 # Result/failure types
│  │  ├─ platform/                   # MethodChannel/EventChannel wrappers
│  │  │  ├─ pdf_text_channel.dart
│  │  │  └─ tts_channel.dart
│  │  └─ utils/                      # tokenizer, bidi helpers, hyphenation hooks
│  ├─ domain/
│  │  ├─ models/                     # Document, Page, Block, Line, Word, ReadingPrefs
│  │  ├─ reflow/                     # tokenizer, spacing engine, bionic(optional)
│  │  └─ services/                   # abstract service interfaces
│  ├─ data/
│  │  ├─ db/                         # drift database (library, bookmarks, progress)
│  │  ├─ prefs/                      # shared_preferences-backed PrefsRepository
│  │  └─ services_impl/              # PdfTextService, OcrService, LangIdService, TtsService
│  └─ features/
│     ├─ library/                    # list of imported docs, import button
│     ├─ reader/                     # the reading surface + ruler + controls
│     │  ├─ reader_screen.dart
│     │  ├─ widgets/reflow_text.dart # RichText builder w/ spacing & highlight
│     │  ├─ widgets/reading_ruler.dart
│     │  └─ controller/reader_controller.dart  # Riverpod notifier
│     ├─ tts/                        # playback controls, voice/speed, highlight state
│     └─ settings/                   # all adjustable prefs (sliders, theme, font)
├─ android/
│  └─ app/src/main/kotlin/.../       # PdfTextExtractor.kt, TtsEngine.kt, MainActivity
├─ assets/fonts/                     # OpenDyslexic, Lexend
├─ test/                             # unit tests (tokenizer, spacing, bionic, reflow)
├─ docs/                             # RESEARCH.md, ARCHITECTURE.md, ROADMAP.md
└─ .github/workflows/                # CI: analyze + test + build signed APK
```

---

## 5. Native platform channels (the two hard bits)

Flutter plugins for these are immature/unreliable (see RESEARCH §3), so we own thin Kotlin
bridges. Interfaces are small and stable.

### 5.1 PDF text extraction — `MethodChannel("dyslexic_reader/pdf_text")`

```
extractText({ path: String, password: String? })
   → { pages: [ { index, width, height,
                  blocks: [ { lines: [ { text,
                              words: [ { text, x, y, w, h } ] } ] } ],
                  hasText: Bool } ] }

hasTextLayer({ path }) → Bool          // quick check to decide reflow vs OCR
```
Kotlin impl: `PdfBox-Android` `PDFTextStripper`, subclassed to capture per‑`TextPosition`
coordinates for reading‑order reconstruction and word boxes. Runs off the main thread.

### 5.2 Text‑to‑speech — `MethodChannel("dyslexic_reader/tts")` + `EventChannel(".../tts_events")`

```
Methods:  init() · getVoices() → [{name, locale, networkRequired, quality}]
          setVoice(name) · setLocale(bcp47) · setRate(0.5..2.0) · setPitch()
          speak({ utteranceId, text }) · stop() · pause() · resume()

Events (stream):  { type: "rangeStart", utteranceId, start, end }   // char offsets → highlight
                  { type: "start"|"done"|"error", utteranceId }
```
Kotlin impl: `android.speech.tts.TextToSpeech` + `UtteranceProgressListener.onRangeStart`.
**Fallback:** if the active engine/voice never emits `onRangeStart` (some OEM/offline
voices), degrade to **sentence‑level** highlighting using utterance start/done boundaries.
Long text is chunked (<4000 chars/utterance) at sentence boundaries.

> OCR (`google_mlkit_text_recognition`) and language ID (`google_mlkit_language_id`) use
> existing, maintained Flutter plugins — no custom bridge needed.

---

## 6. Reading engine (domain, pure Dart — fully unit‑testable)

- **Tokenizer:** text → paragraphs → sentences → words, preserving original **char offsets**
  (needed to map TTS `onRangeStart` ranges back to rendered words). Unicode‑aware
  (grapheme clusters, BiDi).
- **Spacing engine:** maps `ReadingPrefs` → `TextStyle`:
  `letterSpacing`, `wordSpacing`, `height` (line height), `fontSize`, `fontFamily`,
  paragraph spacing, max line width (~65ch). Defaults per BDA/WCAG (see RESEARCH §1).
- **ReflowText widget:** builds a `TextSpan` tree; overlays a highlight `TextStyle` on the
  active word/sentence range during TTS; supports optional **bionic** intra‑word bold
  (toggle, off by default) and optional **syllable** separators (later).
- **Reading ruler:** overlay that dims/tints around the focus band; styles: bar / lightbox /
  shade / underline (CHI‑2023 set). Follows scroll or current TTS line.
- **Themes:** cream / sepia / off‑white / dark / high‑contrast; never pure‑white default.
- **RSVP mode (later):** one‑word‑at‑a‑time presenter using the same tokenizer.

`ReadingPrefs` (persisted): fontFamily, fontSizeSp, letterSpacing, wordSpacing, lineHeight,
paragraphSpacing, maxLineChars, theme, rulerStyle, ttsVoice, ttsRate, bionicEnabled,
syllableEnabled, highlightWord/Sentence.

---

## 7. Multilingual & RTL

- **Three independent languages:** UI locale (`flutter_localizations`), **content** language
  (auto‑detected via ML Kit, user‑overridable), and **TTS voice** language.
- Content language drives **TTS voice selection** and **OCR script** choice.
- **RTL:** wrap reflow surface in `Directionality` derived from detected script; ensure
  ruler, highlight, and bionic logic are direction‑aware. OCR for Arabic/Hebrew scanned docs
  likely needs Tesseract/cloud (ML Kit gap) — deferred.

---

## 8. Persistence & state

- **drift (SQLite):** `documents` (id, title, source path/uri, type, language, pageCount,
  importedAt), `progress` (docId, lastWordIndex/scroll), `bookmarks`.
- **shared_preferences:** `ReadingPrefs` (JSON).
- **Riverpod** providers expose repositories & controllers; reader state (current word,
  playback status, ruler position) lives in a `ReaderController` notifier.
- Imported files copied into app storage (or stored as content‑URIs) so they survive.

---

## 9. Privacy & the hybrid (local + optional cloud) model

- **Default = 100% on‑device:** PdfBox parse, ML Kit OCR/Lang‑ID, system TTS. No network,
  no data leaves the device. This is a stated **differentiator** vs cloud‑bound incumbents.
- **Optional cloud (opt‑in, later):** premium neural voices (Amazon Polly per‑word speech
  marks / Azure / Google) and cloud OCR for non‑Latin scripts. Gated behind an explicit
  setting with a clear privacy notice; API keys via secure storage / user account.
- A future **offline neural TTS** (sherpa_onnx/Piper) gives premium quality *without* cloud.

---

## 10. Deployment — signed APK + CI

- **GitHub Actions** (`.github/workflows/build.yml`): on push/PR/tag →
  `flutter pub get` → `flutter analyze` → `flutter test` → `flutter build apk --release`
  (and `appbundle` for later Play upload). Uploads the APK as a build artifact; on tags,
  attaches it to a GitHub Release.
- **Release signing:** the workflow signs with a keystore injected from repo secrets
  (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
  `ANDROID_KEY_PASSWORD`). If those secrets are absent it falls back to a debug‑signed APK
  so the pipeline is always green. Setup instructions live in the workflow + README.
- **minSdk 24** (Android 7.0, ML Kit‑compatible) / **target = Flutter default**.

---

## 11. Phased roadmap (maps to RESEARCH build‑order)

| Phase | Deliverable | Features |
|---|---|---|
| **0 — Foundation** *(this PR)* | Building, deployable scaffold | Project skeleton, theme system, settings model, **plain‑text reflow reader with adjustable spacing/typography/themes**, CI → signed APK. |
| **1 — PDF** | Open real PDFs | Native PdfBox bridge, text‑layer detection, reflow of born‑digital PDFs, library/import. |
| **2 — TTS** *(highest value)* | Read aloud + highlight | Native TTS bridge, word/sentence highlight sync, speed/voice controls, sentence‑level fallback. |
| **3 — Reading ruler** | Line focus | Ruler styles (bar/lightbox/shade/underline) following scroll & TTS line. |
| **4 — OCR + multilingual** | Scanned PDFs & languages | ML Kit OCR, language auto‑detect → voice/script, RTL. |
| **5 — Extras** | Personalization | BeeLine gradient, RSVP, syllables, OpenDyslexic, optional bionic toggle. |
| **6 — Cloud (opt‑in)** | Premium tier | Offline neural (sherpa_onnx) and/or cloud voices + cloud OCR for non‑Latin. |

---

## 12. Open decisions (to confirm as we go)

- Offline neural TTS (sherpa_onnx) vs cloud for the "premium voice" tier (Phase 6).
- Whether to copy imported files into app storage vs keep content‑URIs (affects "survives reboot/permissions").
- App name & package id (`com.example.dyslexic_reader` placeholder → real id before Play).
- Monetization (affects whether cloud tier needs accounts/billing).
