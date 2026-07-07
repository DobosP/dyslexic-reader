# Roadmap

Build order follows the evidence (see [RESEARCH.md](./RESEARCH.md) §1) and the
architecture phases ([ARCHITECTURE.md](./ARCHITECTURE.md) §11). Highest-value,
strongest-evidence features first.

**Status (2026-07-02): v1.0 launch candidate** — the shipped scope below is
feature-complete (verified status: README.md; publishing gate:
[PUBLISHING.md](./PUBLISHING.md)). Everything still unchecked below =
**post-1.0 backlog**, kept on record as what is intentionally not in v1.0.

## Phase 0 — Foundation ✅
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

## Phase 2 — Active reading (pages, structure, highlighting) ✅ (shipped scope; unchecked = post-1.0)
Redefined with the product owner. Built in this order:
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
- [x] **Outline / structure**: extract the PDF table of contents (PdfBox) + an
      overview; tap a chapter to jump to it
- [x] **Manual highlighting (v1 scope shipped 2026-07-07)**: persisted highlight
      ranges added from long-press / current reading position, listed +
      deletable, rendered inline (recovered re-implementation; see STATUS.md).
- [ ] **Manual highlighting v2**: finger-select arbitrary text + colored
      highlights (single color today — `TODO(recovered)` in
      `lib/features/reader/reader_screen.dart`)  *(post-1.0 backlog)*
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
- [x] Auto-follow the current read-aloud line — shipped (0020d31, 2026-06-27)

## Phase 4 — OCR + multilingual 🚧 (OCR shipped; the rest = post-1.0)
- [x] `google_mlkit_text_recognition` for scanned/image PDFs (auto-detect no text layer) — shipped (4fb9650)
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
- [x] Accessibility pass (TalkBack, dynamic type, contrast) — shipped (a924568)
- [x] Play Store listing assets + privacy policy — listing copy, feature graphic,
      icon & policy text done (docs/STORE_LISTING.md, docs/store/,
      docs/PRIVACY_POLICY.md); screenshots + hosted policy URL still in flight —
      see docs/PUBLISHING.md
