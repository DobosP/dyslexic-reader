> **Reference document (immutable tier) — evidence base, not a status doc.**

# Research Synthesis — Dyslexia‑Friendly Reading App

> Compiled for the **dyslexic‑reader** project. Three areas were researched: (1) the
> evidence base for dyslexia reading aids, (2) how existing apps (commercial &
> open‑source) handle our use case, and (3) the technical building blocks available.
> Sources are linked inline.

---

## 0. Executive summary — the three findings that should drive the product

1. **The famous "dyslexia features" mostly don't work; the boring ones do.** Special
   fonts (OpenDyslexic/Dyslexie), Bionic Reading, and colour‑overlay/"Irlen" therapy
   have **weak, null, or discredited** evidence. **Increased letter/word/line spacing,
   text‑to‑speech with synchronized word highlighting, and reading rulers** have the
   **strongest** evidence. Lead with the latter; offer the former only as harmless,
   opt‑in personalization (never marketed as effective).

2. **Personalization beats any single "magic" setting.** Dyslexia is heterogeneous —
   every strong study found *no single setting works for everyone*. The highest‑leverage
   design decision is **sensible evidence‑based defaults + everything adjustable**
   (this also satisfies WCAG 1.4.12 Text Spacing).

3. **Reflow, don't just overlay.** The best dyslexia experience comes from **extracting a
   PDF's text and re‑rendering it in our own typographic surface** (our fonts, spacing,
   themes, highlighting), falling back to **OCR** for scanned/image PDFs, and keeping an
   "original view" only for layout‑heavy pages.

---

## 1. Evidence‑based reading aids (what to build, ranked by evidence)

### Tier 1 — Strong evidence → MVP

| Technique | Evidence | Default parameters |
|---|---|---|
| **Letter / word / line spacing** | **Zorzi/Ziegler et al. 2012 (PNAS)**: +2.5pt inter‑letter spacing **~halved reading errors** in dyslexic children and boosted speed; benefit was **specific to dyslexic readers**. When spacing is controlled for, the "dyslexia font" effect vanishes (Marinus 2016). | Line height **1.5×**; letter spacing **~0.12× font size** (WCAG) / ~35% of letter width (BDA); word spacing **≥3× letter spacing**; paragraph spacing ≥2× font size. Expose as **sliders**. |
| **TTS + synchronized word/sentence highlighting** ("karaoke") | **Wood, Moxley, Tighe & Wagner 2018** meta‑analysis: 22 studies, 2,942 participants, **d = 0.35, p<.001** for comprehension. Dual‑channel (audio offloads decoding, highlight anchors meaning). | Use engine word‑boundary callbacks; sentence‑level highlight first (easy), word‑level second. Adjustable speed (0.5–2×). |
| **Reading ruler / line focus** | **"Digital Reading Rulers," CHI 2023**: 91 dyslexic + 86 non‑dyslexic readers; all four styles (grey bar, lightbox, shade, underline) improved speed & comprehension, **largest gains for dyslexic readers**. No single style universally preferred → offer choice. | Focus band ~1–3 lines following scroll/tap; dim or tint surroundings; multiple styles. |
| **Typography defaults** (cheap, do anyway) | British Dyslexia Association Style Guide 2023 + W3C. | Clean **sans‑serif**; **14pt+** body; **left‑aligned, never justified**; **~60–70 chars/line**; **off‑white/cream background, not pure white**. |

Sources: [PNAS 2012](https://www.pnas.org/doi/10.1073/pnas.1205566109) · [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC3396504/) · [Wood 2018 meta‑analysis](https://journals.sagepub.com/doi/10.1177/0022219416688170) · [CHI 2023 Reading Rulers](https://dl.acm.org/doi/10.1145/3544548.3581367) · [WCAG 1.4.12 Text Spacing](https://www.w3.org/WAI/WCAG22/Understanding/text-spacing.html) · [BDA Style Guide 2023](https://cdn.bdadyslexia.org.uk/uploads/documents/Advice/style-guide/BDA-Style-Guide-2023.pdf)

### Tier 2 — Moderate / conditional → nice‑to‑have

- **Cream/sepia/off‑white themes (reduced contrast).** Rello & Bigham 2017 (CMU): black‑on‑creme read fastest for dyslexic readers; warm > cool. Evidence for *specific* tints is mixed → ship 3–4 themes, let users pick. [CMU PDF](https://www.cs.cmu.edu/~jbigham/pubs/pdfs/2017/colors.pdf)
- **Syllable splitting / hyphenation** (e.g. `fan·tas·tic`). Helps *struggling* readers but can slow skilled readers; language‑dependent. Off by default. [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC5611416/)
- **RSVP** (one word at a time, fixed position). Weak/anecdotal for dyslexia but cheap to build; offer as optional mode. [Wikipedia](https://en.wikipedia.org/wiki/Rapid_serial_visual_presentation)
- **BeeLine‑style line‑to‑line colour gradient** (fades end of one line into start of next, reducing line‑skipping). One cited study: improved fluency for ~80% of dyslexic readers. Cheap, well‑liked. [BeeLine](https://www.beelinereader.com/)

### Tier 3 — Weak / no / discredited evidence → opt‑in cosmetic at most, do NOT market as effective

- **Specialized dyslexia fonts (OpenDyslexic, Dyslexie).** Wery & Diliberto 2017 (*Annals of Dyslexia*): **no improvement, sometimes slower** vs Arial/Times. Kuster et al. 2018: Dyslexie "neither benefits nor impedes." Apparent benefit traced to spacing, not letterforms. Offer as a *selectable* font only. [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC5629233/) · [Springer](https://link.springer.com/article/10.1007/s11881-017-0154-6)
- **Bionic Reading (bold word‑prefixes).** Readwise large test: readers **2.6 wpm slower**, comprehension identical. Eye‑tracking 2024 (53 ppl): **131.1 vs 130.8 wpm, p=0.9**, eyes don't even fixate the bold letters — mechanism disproven. Offer as an optional toggle if at all. [Readwise](https://blog.readwise.io/bionic-reading-results/) · [PMC 2024](https://pmc.ncbi.nlm.nih.gov/articles/PMC12565662/)
- **Colour overlays / tinted lenses / "Irlen syndrome."** Griffiths et al. 2016 systematic review: effects "small and/or similar to placebo," use "cannot be endorsed." Distinct from the harmless "offer a cream theme." Do **not** brand any tint as therapeutic. [PubMed](https://pubmed.ncbi.nlm.nih.gov/27580753/)

### Recommended build order (by value/evidence)

| Priority | Feature | Evidence | Effort |
|---|---|---|---|
| MVP‑1 | Adjustable letter/word/line spacing (sliders) | Strong | Low |
| MVP‑2 | Typography defaults (sans‑serif, 14pt+, left‑align, ~65ch, off‑white) | Strong | Low |
| MVP‑3 | TTS + synchronized word/sentence highlighting | Strong | High (highest value) |
| MVP‑4 | Reading ruler / line focus (2–3 styles) | Strong | Medium |
| Nice | Theme picker (cream/sepia/dark) | Moderate | Low |
| Nice | BeeLine‑style gradient; RSVP mode | Mixed/weak but cheap | Low |
| Later | Syllable splitting (off by default) | Conditional | Med‑High |
| Opt‑in | OpenDyslexic font (selectable, not default) | Null | Low |
| Skip | Bionic Reading (toggle at most); Irlen overlays as therapy | None/discredited | — |

---

## 2. Competitive landscape — how existing apps handle our use case

### Commercial apps

| App | Platforms | Relevant features | PDF handling | Languages |
|---|---|---|---|---|
| **Speechify** | iOS, Android, Chrome, web, macOS | Neural TTS, word‑by‑word highlight, AI summaries | Imports PDF/EPUB/DOCX/TXT; **OCR** for image PDFs | **60+ languages**, incl. RTL Arabic & Hebrew |
| **Voice Dream Reader** | iOS, Android | Highly configurable TTS + sync highlight; fonts/spacing/colours; DAISY/Bookshare | PDF/Word/EPUB/DAISY; OCR via companion app, **Latin‑only** | ~30 languages / 200+ voices |
| **NaturalReader** | web, iOS, Android, Chrome | Focus mode + real‑time highlight; **OpenDyslexic built in** | Broad formats; **auto‑detects scanned PDFs and prompts OCR** | 50+ languages |
| **Read&Write (Texthelp)** | Win/Mac/Chrome/mobile | TTS, word prediction, dictionaries, masking | OCR via **OmniPage** | Multi‑language |
| **ClaroRead** | Win/Mac/iOS/cloud | TTS + highlight, screen tinting, fonts/spacing | Claro Cloud **OCR** | Multi‑language |
| **Helperbird** | Browser extension | TTS, dyslexia fonts, **reading rulers**, overlays, **bionic mode**, OCR | Works on web PDFs/docs | Many |
| **BeeLine Reader** | Chrome, **PDF viewer**, iOS | Distinctive **eye‑guiding colour gradient** | Dedicated PDF viewer applies gradient over text | — |

### Microsoft Immersive Reader — the canonical feature blueprint

Best **feature checklist** to benchmark against: **Read Aloud** (per‑word highlight, speed,
voice select), **Line Focus** (1/3/5 lines), **Picture Dictionary**, **Syllables**,
**Parts of Speech** colouring, **Translate** (100+ languages), text spacing/fonts/themes/column
width. ([feature guide](https://support.microsoft.com/en-us/office/use-immersive-reader-in-word-a857949f-c91e-4c97-977c-a4efcaf9b3c1))

- **As a dependency it's a poor fit for us:** the Azure AI Immersive Reader is a **hosted web app rendered in an iframe**, requires Azure auth/billing and network, and the open‑source [SDK](https://github.com/microsoft/immersive-reader-sdk) (MIT) was last released Nov 2023.
- **Use it as a spec, not a library.**

### Open‑source projects worth studying

| Project | Stack / License | Why it matters |
|---|---|---|
| **[tomcurryMD/ondevicereaderai](https://github.com/tomcurryMD/ondevicereaderai)** | Kotlin/Compose, **MIT** | **Closest reference to us.** Android doc reader, **100% on‑device neural TTS** (Piper via sherpa‑onnx), sentence highlight, **PDF via PdfBox‑Android**, EPUB, themes/spacing/fonts. Limits: English‑only, no OCR. |
| **[ContentSquare/readapt](https://github.com/ContentSquare/readapt)** | TS/Vue, **Apache‑2.0** | Best reference for **visual‑transformation logic**: configurable spacing, **reading ruler & screen mask**, **syllable breakdown**, **phoneme colouring**, **b/d/p/q confusable‑letter colouring**. |
| **[Gumball12/text-vide](https://github.com/Gumball12/text-vide)** | TS | Clean open‑source **bionic algorithm** (fixation ratio by word length) if we offer the toggle. |
| **[OpenDyslexic](https://opendyslexic.org/)** font | **SIL OFL** | Free to bundle commercially. Latin glyphs only. |
| **[microsoft/immersive-reader-sdk](https://github.com/microsoft/immersive-reader-sdk)** | **MIT** | Feature‑reference samples (incl. Android). |

### How the field handles PDFs (three strategies — we combine them)

1. **Text‑layer extraction + reflow** (born‑digital PDFs) — extract embedded text, re‑render in our clean reflowable layout. *Best for dyslexia aids; full typographic control.* Standard Android lib: **PdfBox‑Android**.
2. **OCR** (scanned/image PDFs) — when no text layer. Auto‑detect like NaturalReader. On‑device: **ML Kit** / **Tesseract**; cloud for non‑Latin scripts.
3. **Overlay on original** (layout‑heavy pages) — keep original render, paint enhancements on top (BeeLine‑style). Preserves tables/figures; limits typography.

**→ Our pipeline:** detect text layer → if present, extract + reflow → else OCR + reflow → offer "original + overlay" fallback.

### Multi‑language & RTL takeaways

- **Separate three things:** UI language, *content* language (auto‑detect), and *TTS voice* language.
- **Auto‑detect** content language (ML Kit Language ID) to pick the right voice/OCR script.
- **RTL (Arabic/Hebrew):** need real BiDi handling in the reflow renderer; bionic bolding & overlays must be RTL‑aware.
- **OCR for non‑Latin/RTL scripts is the field's weak point** — on‑device coverage is limited, so cloud OCR may be needed for Arabic/Hebrew scanned docs. (OpenDyslexic won't help non‑Latin scripts anyway.)
- **Privacy/offline is a real differentiator** — most commercial apps are subscription‑ and cloud‑bound; a fully on‑device pipeline is both a feature and a selling point.

---

## 3. Technical building blocks (evaluated for a Flutter, Android‑first app)

> We chose **Flutter**. The two areas Flutter plugins are weakest are exactly our two
> hardest features — **word‑boundary TTS highlighting** and **PDF text extraction**.
> Mitigation: a **hybrid architecture** with thin **native Android platform‑channel
> bridges** for those two, while everything else stays in Dart. Details in
> [ARCHITECTURE.md](./ARCHITECTURE.md).

### PDF text extraction

| Library | License | Text + positions? | Notes |
|---|---|---|---|
| Android `PdfRenderer` (built‑in) | AOSP | **No** (bitmap only) | Use only as renderer / OCR input. |
| **PdfBox‑Android** (Tom Roush port) | **Apache‑2.0** ✅ | **Yes** (`PDFTextStripper`, per‑glyph `TextPosition`) | **Primary choice.** Pure‑JVM, commercial‑safe. Slow release cadence (v2.0.27, Jan 2023). |
| **PDFium** (Google) | **BSD‑3** ✅ | Yes (`FPDFText_*` + char boxes) | Fallback for high‑fidelity render / perf. |
| iText 8 | **AGPL or paid** ⚠️ | Yes (excellent) | AGPL forces open‑sourcing the whole app — avoid for commercial. |
| MuPDF | **AGPL or paid** ⚠️ | Yes (structured) | Same AGPL blocker. |

> Reading order is **heuristic everywhere** (PDF stores glyph positions, not sentences) — budget for column/paragraph reconstruction regardless of library.

### OCR (scanned PDFs/images)

- **Google ML Kit Text Recognition v2** — on‑device, free, structured output (block/line/word + boxes + language). **5 scripts:** Latin, Chinese, Devanagari, Japanese, Korean. Unbundled models ~260KB/script. **Gaps: Arabic, Cyrillic, Greek, Thai, Hebrew.** [docs](https://developers.google.com/ml-kit/vision/text-recognition/v2/android)
- **Tesseract4Android** (Apache‑2.0) — 100+ languages via downloadable `traineddata`. Fallback for scripts ML Kit can't handle. [repo](https://github.com/adaptech-cz/Tesseract4Android)
- **Pattern:** ML Kit first → Tesseract for unsupported scripts → optional cloud (Google Cloud Vision) for hardest cases.

### Text‑to‑speech

- **Android native `TextToSpeech`** — free, multilingual, offline‑capable. Word highlighting via **`UtteranceProgressListener.onRangeStart(start,end,frame)`** — **only path with first‑class word‑boundary callbacks.** Works with the **Google TTS engine**; some OEM/offline voices don't supply timing → build a **sentence‑level fallback**. ~4000‑char/utterance limit (chunk long text). [docs](https://developer.android.com/reference/android/speech/tts/UtteranceProgressListener)
- **Offline neural option:** **Piper via sherpa‑onnx** (as in `ondevicereaderai`) — high‑quality offline voices, but ship a model per language.
- **Optional cloud premium tier:** **Amazon Polly** (per‑word Speech Marks — cleanest sync), Google Cloud TTS, Azure Neural. Online + paid; keep optional. ([comparison](https://www.speechmatics.com/company/articles-and-news/best-tts-apis-in-2025-top-12-text-to-speech-services-for-developers))
- **Flutter note:** `flutter_tts` exposes progress callbacks only on some engines; word‑boundary sync is **less reliable than native** → we bridge TTS natively (see architecture).

### Language detection

- **ML Kit Language Identification** — on‑device, free, **100+ languages**, BCP‑47 codes + confidence, returns `und` when unsure (→ manual picker fallback). Use it to auto‑select TTS `Locale` and OCR script. [docs](https://developers.google.com/ml-kit/language/identification/android)

### Styled‑text rendering (Flutter)

- Flutter's `RichText`/`TextSpan` + `TextStyle` handle per‑word & **intra‑word** styling (for an optional bionic toggle), `letterSpacing`, `height` (line height), `wordSpacing`, custom fonts (OpenDyslexic/Lexend), and live highlight via rebuilds. Use **lazy/virtualized lists** (one paragraph/page per item) for large docs. RTL via `Directionality`.

### Why these choices are commercialization‑safe

The whole recommended stack is **Apache‑2.0 / BSD / SIL‑OFL / first‑party** — deliberately
avoiding the **AGPL traps** in iText and MuPDF.

### Risks to validate early

1. **PDF reading order** is heuristic — budget for paragraph/column reconstruction.
2. **`onRangeStart` engine‑dependent** — guaranteed on Google TTS, not all engines → sentence‑level fallback.
3. **ML Kit = 5 scripts only** — Tesseract is the multilingual OCR safety net.
4. **Cloud TTS/OCR = recurring cost + online** — keep optional, not default.
5. **PdfBox‑Android cadence slow** — PDFium is the fallback engine.

---

## 4. What *this* app should do (synthesis)

1. **Core feature = TTS with synchronized word/sentence highlighting** (strongest evidence; every leader centers on it). Native bridge for reliability; offline neural voices as a privacy/quality upgrade.
2. **Reflow PDFs into our own typographic surface** via PdfBox‑Android; OCR fallback (ML Kit → Tesseract) with auto text‑layer detection.
3. **Use Immersive Reader's menu as the roadmap** (Read Aloud, Line Focus, syllables, translate, spacing/themes) — as a spec, not a dependency.
4. **Ship cheap high‑impact visual aids:** reading ruler/line focus, BeeLine‑style gradient, theme/tint picker.
5. **Fonts are options, not a fix:** bundle OpenDyslexic (OFL) + clean sans‑serifs; lead with generous **spacing** controls.
6. **Bionic reading = optional toggle**, never the headline.
7. **Multilingual + RTL from day one:** separate UI/content/voice language; auto‑detect content; BiDi‑correct rendering; plan cloud OCR for non‑Latin scanned docs.
8. **Lead on privacy/offline** as the differentiator vs subscription/cloud incumbents.

**Most useful artifacts to study directly:** `tomcurryMD/ondevicereaderai` (Android+offline TTS, MIT), `ContentSquare/readapt` (visual‑transform logic, Apache‑2.0), `Gumball12/text-vide` (bionic algorithm), OpenDyslexic (OFL), `microsoft/immersive-reader-sdk` (feature reference, MIT).
