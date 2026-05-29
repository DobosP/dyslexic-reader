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

## Phase 2 — Read-aloud + highlighting (highest value)
- [ ] Native bridge: `TtsEngine` (Android `TextToSpeech` + `onRangeStart`)
- [ ] Word + sentence highlight synced to audio; play/pause, speed, voice picker
- [ ] Sentence-level fallback when an engine emits no word boundaries
- [ ] Chunk long text at sentence boundaries (<4000 chars/utterance)

## Phase 3 — Reading ruler / line focus
- [ ] Ruler styles: bar / lightbox / shade / underline (CHI-2023 set)
- [ ] Follows scroll and the current read-aloud line

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
