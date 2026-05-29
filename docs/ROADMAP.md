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

## Phase 1 — PDF import & reflow
- [ ] `file_picker` + share-intent to open PDFs and `.txt`
- [ ] Native bridge: `PdfTextExtractor` (PdfBox-Android) — text + word positions
- [ ] Text-layer detection → reflow born-digital PDFs
- [ ] Document library (drift): list, reopen, reading progress
- [ ] "Original view" fallback (pdfrx) for layout-heavy pages

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
