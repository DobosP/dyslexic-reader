# Architecture — dyslexic‑reader

Android‑first **Flutter** app that opens PDF, Word (.docx) and plain-text files and re‑renders them in a
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
4. **Flutter for everything except the one hard native bit.** PDF text extraction goes
   through a thin native bridge (§5.1); TTS and OCR are plugins (§5.2); everything else is Dart.
5. **Multilingual, RTL‑ready.** Separate UI language, content language and TTS voice; content
   auto‑detect and BiDi reflow are post‑1.0 (§11).

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
│   • PrefsRepository  • LibraryIndexStore (JSON, atomic)            │
│   • LibraryController  • PdfTextChannel  • OcrEngine  • FlutterTts │
└─────────────┬───────────────────────────────┬────────────────────┘
              │ MethodChannel bridges          │ pub.dev plugins
              ▼                                 ▼
┌──────────────────────────────┐   ┌──────────────────────────────┐
│ Native Android (Kotlin)      │   │ Flutter plugins               │
│  • MainActivity              │   │  • google_mlkit_text_recog.   │
│    (pdf_text + incoming      │   │    + mobile_ocr (OCR)         │
│     channels, PdfRenderer)   │   │  • flutter_tts (word‑range    │
│  • StructuredTextStripper    │   │    progress → highlight)      │
│    (PdfBox‑Android, Apache2) │   │  • archive + xml (.docx)      │
└──────────────────────────────┘   │  • file_selector, share, etc. │
                                   │  • (later) sherpa_onnx neural │
                                   │    offline TTS                │
                                   └──────────────────────────────┘
```

### Document pipeline

```
import (file_selector / share intent / paste)
   │
   ├─ PDF ──► PdfTextChannel.extractText()  ─► has usable text layer?
   │            (native PdfBox bridge)            │ yes ─► structured text (pages/blocks/lines/words)
   │                                              │ no  ─► render page bitmap ─► OcrEngine (Paddle → ML Kit fallback)
   │                                                                            └─ script unsupported? ─► (later) Tesseract / cloud
   │
   └─ TXT / pasted / DOCX ──► plain text (DOCX: word/document.xml via archive + xml)
        │
        ▼
   (language auto-detect: post-1.0; TTS voice chosen in Settings)
        │
        ▼
   Tokenizer ─► Document model (paragraphs → sentences → words, with char offsets)
        │
        ▼
   Reading surface  ── applies ReadingPrefs (spacing, font, theme, ruler, bionic?)
        │                renders reflowed RichText in a virtualized list
        ▼
   FlutterTts.speak(chunk)  ── setProgressHandler (onRangeStart) → highlight current word inside the ≤2-line chunk
```

---

## 3. Technology stack

| Concern | Choice | License | Why |
|---|---|---|---|
| Framework / UI | **Flutter (stable) + Material 3** | BSD | Chosen by product owner; one codebase, iOS later. |
| Language | **Dart**; **Kotlin** for native bridges | — | — |
| State management | **Riverpod 2** (`flutter_riverpod`) | MIT | Compile‑safe, testable, no `BuildContext` coupling. |
| Routing | **Navigator** + `IndexedStack` shell (`lib/app/app_shell.dart`) | — | No router package; phone pushes full‑screen routes, wide layouts embed the reader (ADR-0003). |
| Library index | **JSON file** written atomically (temp → primary, `.bak` backup, `.corrupt` quarantine) | — | `lib/core/storage/atomic_file_writer.dart`, `lib/features/library/library_index_store.dart`. Entries carry progress, bookmarks, notes, highlight ranges. |
| Simple settings | **shared_preferences** | BSD | ReadingPrefs key‑values. |
| PDF **text** extraction | **Native bridge → PdfBox‑Android** | Apache‑2.0 | Only reliable text+positions on Android; commercial‑safe. |
| PDF **page render** (original view) | **Android `PdfRenderer`** (built-in) via native bridge | AOSP | No extra dep; renders scanned/layout-heavy pages and is the OCR raster source. |
| OCR | **google_mlkit_text_recognition** + `mobile_ocr` (ente-io) — `lib/data/services/ocr_service.dart:1-2` | Apache‑2.0 | On‑device; the app uses the Latin recognizer (`lib/data/services/ocr_service.dart:21`) plus PaddleOCR; more scripts later. |
| Language detection | not implemented (post‑1.0) | — | See [`ROADMAP.md`](./ROADMAP.md) Phase 4; voice is chosen manually in Settings. |
| TTS (word‑sync) | **`flutter_tts`** plugin → Android `TextToSpeech` word‑range progress | MIT | `setProgressHandler` drives the word highlight (`lib/features/reader/reader_screen.dart:147`). |
| TTS (offline neural, later) | **sherpa_onnx** (Piper) | Apache‑2.0 | Privacy/quality upgrade; per‑language model. |
| Fonts | **OpenDyslexic** (opt‑in), **Atkinson Hyperlegible**, **Lexend**, system sans‑serif | OFL | Spacing matters more than font; offer choice. |
| File import | **file_selector** (official) + native open‑with/share intents | BSD | Open/paste/share PDFs & text. |
| Lint | **flutter_lints** / `analysis_options.yaml` | BSD | — |

> **Licensing guardrail:** everything above is **Apache‑2.0 / BSD / MIT / OFL / first‑party**.
> We deliberately avoid **iText** and **MuPDF** (AGPL → would force open‑sourcing the whole app).

---

## 4. Project structure (feature‑first)

Feature‑first layout: `lib/domain/` is pure Dart (tokenizer, paginator, reflow, document structure —
unit‑tested without Flutter), `lib/core/` holds the atomic file writer and the two platform channels,
`lib/data/` the prefs repository and OCR service, `lib/features/` the library / reader / settings /
onboarding screens, and `lib/app/` the adaptive shell and theme tokens. The authoritative directory
map is [`README.md`](../README.md) §Project layout; native Kotlin lives under
`android/app/src/main/kotlin/`.

---

## 5. Native platform channels and TTS

PDF text extraction has no reliable Flutter plugin (see RESEARCH §3), so we own a thin Kotlin
bridge for it; word‑synced TTS ships as a plugin (§5.2). Interfaces are small and stable.

### 5.1 PDF text extraction — `MethodChannel("dyslexic_reader/pdf_text")`

```
extractText({ path: String, password: String? })
   → { blocks:    [ { type: "h1"|"h2"|"h3"|"p", text: String, page: Int } ],
       pageCount: Int,
       hasText:   Bool,
       outline:   [ { title: String, level: Int, page: Int } ] }

renderPage({ path: String, pageIndex: Int, targetWidth: Int }) → PNG bytes (Uint8List)
```
Kotlin impl: `PdfBox-Android` `PDFTextStripper`, subclassed to capture per‑`TextPosition`
coordinates for typed blocks (h1–h3 / p) from coordinate + font heuristics. Runs off the main thread.

### 5.2 Text‑to‑speech — `flutter_tts` plugin

Implemented with the `flutter_tts` plugin rather than a hand‑written channel: it wraps
`android.speech.tts.TextToSpeech` and surfaces `UtteranceProgressListener.onRangeStart` as progress
callbacks; `ReaderScreen` registers `setProgressHandler` to move the word highlight
(`lib/features/reader/reader_screen.dart:145-147`). The only hand‑written channels are
`dyslexic_reader/pdf_text` and `dyslexic_reader/incoming`
(`android/app/src/main/kotlin/com/dobosp/dyslexic_reader/MainActivity.kt:29-30`).

**Fallback:** text is spoken one chunk (≤ 2 rendered lines) per utterance; engines/voices that
never emit `onRangeStart` leave the chunk‑band highlight in place and the completion handler
advances to the next chunk.

> OCR (`google_mlkit_text_recognition`, `mobile_ocr`) and TTS (`flutter_tts`) use existing,
> maintained Flutter plugins — no custom bridge needed.

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

- **Three independent languages:** UI locale (`flutter_localizations` — post‑1.0), **content** language
  (auto‑detection is post‑1.0 — ROADMAP Phase 4; chosen manually in Settings today), and **TTS voice** language.
- **(post‑1.0)** Content language will drive **TTS voice selection** and **OCR script**
  choice; today OCR is Latin‑script ML Kit or PaddleOCR (`lib/data/services/ocr_service.dart:21`).
- **(post‑1.0) RTL:** wrap reflow surface in `Directionality` derived from detected script; ensure
  ruler, highlight, and bionic logic are direction‑aware. OCR for Arabic/Hebrew scanned docs
  likely needs Tesseract/cloud (ML Kit gap) — deferred.

---

## 8. Persistence & state

- **Library index (JSON, atomic):** one `index.json` per library with entries (title, source, type, reading
  progress, bookmarks, notes, highlight ranges — `lib/domain/models/library_entry.dart`); writes go temp → rename,
  previous good copy kept as `index.json.bak`, unreadable primaries quarantined as `index.json.corrupt`
  (`lib/features/library/library_index_store.dart:5-23`). Invariant: never silently lose a library
  (`AGENTS.md` §Safety).
- **shared_preferences:** `ReadingPrefs` (JSON).
- **Riverpod** providers expose repositories & controllers (`ReadingPrefsController extends
  Notifier<ReadingPrefs>` — `lib/features/settings/reading_prefs_controller.dart:8`); reader state is
  local to the screen — highlight in a `ValueNotifier<ReadingHighlight>`
  (`lib/features/reader/reader_screen.dart:42`), pagination in `PageReaderController extends
  ChangeNotifier` (`lib/features/reader/widgets/paginated_reader.dart:42`).
- Imported PDFs are copied into app storage (`library/`) with a cached typed‑blocks file per document,
  so they survive permission/URI revocation.

---

## 9. Privacy & the hybrid (local + optional cloud) model

- **Default = 100% on‑device:** PdfBox parse, ML Kit / mobile_ocr OCR, system TTS. No network,
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
  so the pipeline is always green. Setup instructions: [`PUBLISHING.md`](./PUBLISHING.md) Step 2.
- **minSdk 24** (Android 7.0, ML Kit‑compatible) / **target = Flutter default**.

---

## 11. Phased roadmap (maps to RESEARCH build‑order)

Shipped scope per phase is tracked in [ROADMAP.md](./ROADMAP.md); current state in
[`STATUS.md`](../STATUS.md). This section describes the phases themselves.

| Phase | Status | Deliverable | Features |
|---|---|---|---|
| **0 — Foundation** | ✅ shipped | Building, deployable scaffold | Project skeleton, theme system, settings model, **plain‑text reflow reader with adjustable spacing/typography/themes**, CI → signed APK. |
| **1 — PDF** | ✅ shipped | Open real PDFs | Native PdfBox bridge, text‑layer detection, reflow of born‑digital PDFs, library/import. |
| **2 — TTS** *(highest value)* | ✅ shipped | Read aloud + highlight | Word/sentence highlight sync (`flutter_tts` progress handler), speed/voice/pitch controls, chunk‑level fallback. |
| **3 — Reading ruler** | ✅ shipped | Line focus | Ruler styles (bar/lightbox/shade/underline) following scroll & TTS line; auto‑follow. |
| **4 — OCR + multilingual** | 🚧 OCR shipped; lang‑ID + RTL **not implemented** | Scanned PDFs & languages | ML Kit OCR ✅; language auto‑detect → voice/script and RTL remain post‑1.0. |
| **5 — Extras** | post‑1.0 backlog | Personalization | BeeLine gradient, RSVP, syllables, OpenDyslexic, optional bionic toggle. |
| **6 — Cloud (opt‑in)** | post‑1.0 backlog | Premium tier | Offline neural (sherpa_onnx) and/or cloud voices + cloud OCR for non‑Latin. |

---

## 12. Open decisions (to confirm as we go)

- Offline neural TTS (sherpa_onnx) vs cloud for the "premium voice" tier (Phase 6).
- Copy imported files into app storage vs keep content‑URIs: **resolved** — copy (§8).
- App name & package id: **resolved** — "Dyslexic Reader" / `com.dobosp.dyslexic_reader`.
- Monetization: **resolved** — free, no ads, no IAP (on‑device is the differentiator).
