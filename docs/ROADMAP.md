# Roadmap

Build order follows the evidence (see [RESEARCH.md](./RESEARCH.md) §1) and the
architecture phases ([ARCHITECTURE.md](./ARCHITECTURE.md) §11). Highest-value,
strongest-evidence features first.

## Phase 0 — Foundation ✅ (current)
- [x] Flutter project scaffold (Android), Material 3
- [x] `ReadingPrefs` model + JSON persistence (shared_preferences)
- [x] Theme system: cream / sepia / off-white / dark / high-contrast (no pure white)
- [x] Tokenizer (paragraphs + word offsets) — pure Dart, unit-tested
- [x] Reflow reader: adjustable font, size, letter/word/line spacing, paragraph spacing, line width
- [x] Settings screen with live preview; optional bionic toggle (off by default)
- [x] Library screen: read bundled sample / paste your own text
- [x] CI: `flutter analyze` + `flutter test` + build signed APK (GitHub Actions)

## Phase 1 — PDF import & reflow ✅
- [x] Import PDFs and `.txt` via the official `file_selector`
- [x] Open-with & share-to intents (PDF/text opened or shared from other apps)
- [x] Native bridge: text extraction (PdfBox-Android) + page render (Android PdfRenderer)
- [x] Text-layer detection → reflow born-digital PDFs
- [x] Scanned/image PDFs imported and shown in an original page view
- [x] On-device document library (JSON index + cached text): list, reopen, delete
- [x] Remember & restore reading position per document
- [ ] Word-position extraction (for highlight/ruler) — folded into the TTS phase
- [ ] Migrate the flat JSON library index to drift if it outgrows a single file

## Phase 2 — Active reading (pages, structure, highlighting) 🚧
Redefined with the product owner. Building in this order:
- [x] **Pages & progress**: paginate into screen-fit pages (swipe/turn); remember
      reading position (char-offset based, survives font changes); bookmarks
- [x] **Fast loading**: incremental (lazy) pagination — first page(s) open
      instantly, the rest fill in the background and just-in-time on swipe
- [x] **Updatable debug installs**: stable committed debug key + auto versionCode
      so debug APKs install over each other; open-with/share also accepts text
- [x] **Scroll reading**: vertical virtualized scroll (windowed render, fast jumps)
- [x] **Structured PDF text**: on-device extractor rebuilds headings & paragraphs
      (PdfBox subclass), strips running headers/footers, de-hyphenates — see
      docs/PDF_PARSING.md
- [ ] **Outline / structure**: extract the PDF table of contents (PdfBox) + an
      overview; tap a chapter to jump to it
- [ ] **Manual highlighting**: finger-select text, colored highlights saved per
      book, revisitable list  *(queued)*
- [ ] **AI summary**: whole-book / per-chapter summaries  *(parked — revisit cloud powering + API key)*
- [x] **Read-aloud (text-to-speech)**: chunk-level highlight synced to playback,
      ±15s skip, resume where paused, in-reader speed control (`flutter_tts`)
- [x] **Read-aloud voice picker** + speed + pitch (`flutter_tts` getVoices)
- [x] **Word-level highlight sync**: the spoken word is highlighted inside the
      chunk band via `flutter_tts` `setProgressHandler` (graceful fallback to
      chunk-level on engines without word boundaries)
- [x] **In-document search**: case-insensitive, match count + next/prev, jump &
      flash; reader app bar consolidated (primary actions + overflow menu)

## Phase 3 — Reading ruler / line focus ✅
- [x] Ruler styles: tint bar / underline / shade / spotlight (CHI-2023 set)
- [x] Draggable focus band; text scrolls underneath (typoscope)
- [ ] Auto-follow the current read-aloud line — *fast-follow 1.1*

## Phase 4 — OCR + multilingual
- [ ] `google_mlkit_text_recognition` for scanned/image PDFs (auto-detect no text layer)
- [ ] `google_mlkit_language_id` → auto-pick TTS voice + OCR script
- [ ] RTL (Arabic/Hebrew) reflow; Tesseract/cloud OCR for non-Latin scripts

## Phase 5 — Extras / personalization
- [ ] BeeLine-style line-to-line colour gradient
- [ ] RSVP one-word mode
- [ ] Syllable splitting (off by default)
- [ ] OpenDyslexic already bundled; refine font picker

## Phase 6 — Optional cloud / premium (hybrid)
- [ ] Offline neural voices (sherpa_onnx / Piper) and/or cloud TTS (Polly/Azure/Google)
- [ ] Cloud OCR for hardest non-Latin scanned docs
- [ ] Explicit opt-in + privacy notice; on-device stays the default

## Cross-cutting
- [ ] iOS target (Flutter makes this incremental once native bridges have iOS impls)
- [ ] Localized UI (`flutter_localizations`)
- [ ] Accessibility pass (TalkBack, dynamic type, contrast)
- [ ] Play Store listing assets + privacy policy (when publishing publicly)
